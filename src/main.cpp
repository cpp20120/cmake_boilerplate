#include <iostream>
#include <algorithm>
#include <atomic>
#include <cassert>
#include <chrono>
#include <condition_variable>
#include <deque>
#include <functional>
#include <future>
#include <iostream>
#include <limits>
#include <memory>
#include <mutex>
#include <optional>
#include <queue>
#include <sstream>
#include <stdexcept>
#include <stop_token>
#include <string>
#include <thread>
#include <type_traits>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

#if defined(_WIN32) || defined(_WIN64)
#define THREADPOOL_WINDOWS 1
#include <windows.h>
#undef max
#elif defined(__linux__) || defined(__APPLE__)
#define THREADPOOL_POSIX 1
#include <pthread.h>
#include <unistd.h>
#endif

namespace thread_pool {
template <typename T>
class lock_free_queue {
  struct Node {
    T data;
    Node *next;

    explicit Node(T value) : data(std::move(value)), next(nullptr) {}
  };

  std::atomic<Node *> head;
  std::atomic<Node *> tail;

 public:
  lock_free_queue() {
    Node *dummy = new Node(T{});
    head.store(dummy);
    tail.store(dummy);
  }

  ~lock_free_queue() {
    Node *current = head.load();
    while (current) {
      Node *next = current->next;
      delete current;
      current = next;
    }
  }

  void push(T value) {
    Node *new_node = new Node(std::move(value));
    Node *old_tail = tail.exchange(new_node);
    old_tail->next = new_node;
  }

  std::optional<T> pop() {
    Node *old_head = head.load();
    Node *next = old_head->next;

    if (!next) return std::nullopt;

    head.store(next);
    T value = std::move(next->data);
    delete old_head;
    return value;
  }

  [[nodiscard]] bool empty() const { return head.load()->next == nullptr; }
};

class task_cancelled_error final : public std::runtime_error {
 public:
  task_cancelled_error() : std::runtime_error("Task was cancelled") {}
};

struct TaskMetadata {
  std::string name;
  std::chrono::time_point<std::chrono::steady_clock> submission_time;
  std::optional<std::chrono::time_point<std::chrono::steady_clock>> start_time;
  std::optional<std::chrono::time_point<std::chrono::steady_clock>>
      completion_time;
  std::thread::id worker_thread_id;
  size_t memory_usage_estimate = 0;  // bytes
  std::unordered_set<std::string> tags;
  std::optional<std::chrono::steady_clock::duration> timeout;
  std::optional<std::chrono::steady_clock::duration> execution_time;
  std::optional<std::chrono::steady_clock::duration> wait_time;
  std::optional<std::chrono::steady_clock::duration> queue_time;
  std::optional<std::chrono::steady_clock::duration> priority;
  std::vector<size_t> dependencies;
};

struct TaskHandle {
  std::shared_ptr<std::atomic<bool>> cancelled;
  std::shared_ptr<TaskMetadata> metadata;
  size_t task_id;

  [[nodiscard]] bool is_ready() const { return !cancelled || !cancelled->load(); }
};

thread_local int lock_level = 0;

class hierarchical_mutex {
  std::mutex mtx;
  int level;

 public:
  explicit hierarchical_mutex(int l) : level(l) {}

  void lock() {
    if (lock_level >= level) {
      throw std::logic_error("Lock hierarchy violation");
    }
    mtx.lock();
    lock_level = level;
  }

  void unlock() {
    if (lock_level != level) {
      throw std::logic_error("Lock hierarchy violation");
    }
    lock_level = 0;
    mtx.unlock();
  }
};
template <typename PriorityType>
class thread_pool;

class DependencyGraph {
  struct Node {
    std::shared_ptr<std::packaged_task<void()>> task;
    std::unordered_set<size_t> dependents;
    std::atomic<int> dependency_count{0};
    TaskMetadata metadata;
    std::shared_ptr<std::atomic<bool>> cancelled =
        std::make_shared<std::atomic<bool>>(false);
    std::atomic<bool> dependencies_processed{false};
    mutable std::mutex mutex;

    bool is_ready() const {
      return !cancelled->load() &&
             (dependency_count.load() == 0 || dependencies_processed.load());
    }
  };

  mutable std::mutex graph_mutex;
  mutable std::mutex queue_mutex;
  std::condition_variable tasks_completed_condition;
  std::unordered_map<size_t, Node> nodes;
  std::atomic<uint64_t> next_task_id{0};



  bool has_cycle_util(const size_t node_id, std::unordered_set<size_t> &visited,
                      std::unordered_set<size_t> &recursion_stack) const {
    if (!recursion_stack.contains(node_id)) {
      visited.insert(node_id);
      recursion_stack.insert(node_id);

      if (const auto it = nodes.find(node_id); it != nodes.end()) {
        for (size_t dependent_id : it->second.dependents) {
          if (!visited.contains(dependent_id)) {
            if (has_cycle_util(dependent_id, visited, recursion_stack)) {
              return true;
            }
          } else if (recursion_stack.contains(dependent_id)) {
            return true;
          }
        }
      }
    }
    recursion_stack.erase(node_id);
    return false;
  }

  void notify_dependents(size_t completed_id,
                         const std::unordered_set<size_t> &dependents) {
    if (dependents.empty()) return;

    std::unique_lock lock(graph_mutex);
    for (size_t dependent_id : dependents) {
      if (auto dep_it = nodes.find(dependent_id); dep_it != nodes.end()) {
        std::unique_lock node_lock(dep_it->second.mutex);
        if (const int new_count = --dep_it->second.dependency_count; new_count <= 0) {
          dep_it->second.dependencies_processed.store(true);
        }
      }
    }
    tasks_completed_condition.notify_all();
  }



 public:


  std::mutex &get_graph_mutex() const { return graph_mutex; }
  std::unordered_map<size_t, Node> &get_nodes() { return nodes; }



   void verify_lock_state() {
    if (!graph_mutex.try_lock()) {
      std::cerr << "Graph mutex is locked!\n";
      return;
    }
    graph_mutex.unlock();

    for (auto &[id, node] : nodes) {
      if (!node.mutex.try_lock()) {
        std::cerr << "Node " << id << " mutex is locked!\n";
        continue;
      }
      node.mutex.unlock();
    }
  }
  void debug_print() const {
    std::scoped_lock lock(graph_mutex);
    std::cout << "Dependency Graph:\n";
    std::cout << "Total nodes: " << nodes.size() << "\n";

    for (const auto &[id, node] : nodes) {
      std::scoped_lock node_lock(node.mutex);
      std::cout << "  Task " << id << ": "
                << "deps=" << node.dependency_count.load()
                << ", dependents=" << node.dependents.size()
                << ", cancelled=" << node.cancelled->load() << "\n";
    }
  }

  bool emergency_process_blocked_tasks(bool force = false) {
    bool processed = false; {
      std::vector<size_t> to_remove;
      std::unique_lock graph_lock(graph_mutex);
      for (auto &[id, node] : nodes) {
        std::unique_lock node_lock(node.mutex);

        bool all_deps_completed = true;
        for (auto dep_id : node.metadata.dependencies) {
          if (nodes.contains(dep_id)) {
            all_deps_completed = false;
            break;
          }
        }

        if (all_deps_completed || force) {
          node.dependencies_processed.store(true);
          to_remove.push_back(id);
          processed = true;
        }
      }
    }

    return processed;
  }

  bool has_cycle() const {
    std::scoped_lock lock(graph_mutex);
    std::unordered_set<size_t> visited;
    std::unordered_set<size_t> recursion_stack;

    for (const auto &[id, node] : nodes) {
      if (!visited.contains(id)) {
        if (has_cycle_util(id, visited, recursion_stack)) {
          return true;
        }
      }
    }
    return false;
  }

  TaskHandle add_task(std::packaged_task<void()> task, TaskMetadata metadata,
                      const std::vector<TaskHandle> &dependencies = {}) {
    const size_t id = next_task_id.fetch_add(1);

    const auto task_ptr =
        std::make_shared<std::packaged_task<void()>>(std::move(task));
    const auto cancelled = std::make_shared<std::atomic<bool>>(false);
    const auto meta_ptr = std::make_shared<TaskMetadata>(std::move(metadata));
    {
      std::scoped_lock lock(graph_mutex);
      Node &node = nodes[id];
      node.task = task_ptr;
      node.metadata = *meta_ptr;
      node.cancelled = cancelled;
      node.dependency_count.store(static_cast<int>(dependencies.size()));

      for (const auto &dep : dependencies) {
        nodes[dep.task_id].dependents.insert(id);
        meta_ptr->dependencies.push_back(dep.task_id);
      }
    }

    return TaskHandle{cancelled, meta_ptr, id};
  }

  bool is_ready(const Node &node) const {
    if (node.cancelled->load()) return false;
    if (node.dependency_count.load() == 0) return true;

    for (auto dep_id : node.metadata.dependencies) {
      if (nodes.contains(dep_id)) return false;  // dependency still exists
    }
    return true;  // all dependencies completed
  }

std::optional<std::packaged_task<void()>> try_get_ready_task() {
    std::optional<std::packaged_task<void()>> result;
    std::unordered_set<size_t> dependents_to_notify;
    size_t completed_id = 0;

    std::unique_lock graph_lock(graph_mutex, std::try_to_lock);
    if (!graph_lock.owns_lock()) {
      return std::nullopt;
    }

    for (auto it = nodes.begin(); it != nodes.end();) {
      std::unique_lock node_lock(it->second.mutex, std::try_to_lock);
      if (!node_lock.owns_lock()) {
        ++it;
        continue;
      }

      if (it->second.is_ready() && it->second.task) {
        result = std::move(*it->second.task);
        completed_id = it->first;
        dependents_to_notify = it->second.dependents;

        it = nodes.erase(it);


        node_lock.unlock();

        break;
      }
      ++it;
    }

    if (result) {
      graph_lock.unlock();
      notify_dependents(completed_id, dependents_to_notify);
    }

    return result;
  }

  void mark_completed(const size_t task_id) {
    std::vector<size_t> dependents_to_notify;
    {
      std::unique_lock lock(graph_mutex);
      const auto it = nodes.find(task_id);
      if (it == nodes.end()) return;

      dependents_to_notify.assign(it->second.dependents.begin(),
                                  it->second.dependents.end());
      nodes.erase(it);
    }

    if (!dependents_to_notify.empty()) {
      std::unique_lock lock(graph_mutex);
      for (size_t dependent_id : dependents_to_notify) {
        if (auto dep_it = nodes.find(dependent_id); dep_it != nodes.end()) {
          dep_it->second.dependency_count.fetch_sub(1);
        }
      }
    }
    tasks_completed_condition.notify_all();
  }

  bool has_ready_task() const {
    std::scoped_lock lock(graph_mutex);
    for (const auto &[id, node] : nodes) {
      std::scoped_lock node_lock(node.mutex);
      if (node.dependency_count.load() == 0 && !node.cancelled->load() &&
          node.task) {
        return true;
      }
    }
    return false;
  }

  size_t pending_count() const {
    std::scoped_lock lock(graph_mutex);
    return nodes.size();
  }

  void clear_all() {
    std::scoped_lock lock(graph_mutex);
    nodes.clear();
  }
};

template <typename PriorityType = int>
class thread_pool {
  friend class DependencyGraph;

  struct PrioritizedTask {
    PriorityType priority;
    std::packaged_task<void()> task;
    std::shared_ptr<TaskMetadata> metadata;
    std::shared_ptr<std::atomic<bool>> cancelled;

    PrioritizedTask();

    PrioritizedTask(PriorityType priority, std::packaged_task<void()> task,
                    std::shared_ptr<TaskMetadata> metadata,
                    std::shared_ptr<std::atomic<bool>> cancelled)
        : priority(priority),
          task(std::move(task)),
          metadata(std::move(metadata)),
          cancelled(std::move(cancelled)) {}

    PrioritizedTask(const PrioritizedTask &) = delete;
    PrioritizedTask &operator=(const PrioritizedTask &) = delete;

    PrioritizedTask(PrioritizedTask &&other) noexcept
        : priority(other.priority),
          task(std::move(other.task)),
          metadata(std::move(other.metadata)),
          cancelled(std::move(other.cancelled)) {}

    PrioritizedTask &operator=(PrioritizedTask &&other) noexcept {
      if (this != &other) {
        priority = other.priority;
        task = std::move(other.task);
        metadata = std::move(other.metadata);
        cancelled = std::move(other.cancelled);
      }
      return *this;
    }

    bool operator<(const PrioritizedTask &other) const {
      return priority < other.priority;
    }
  };

  struct TaskComparator {
    bool operator()(const std::shared_ptr<PrioritizedTask> &lhs,
                    const std::shared_ptr<PrioritizedTask> &rhs) const {
      return *rhs < *lhs;
    }
  };

  struct ThreadContext {
    std::deque<PrioritizedTask> queue;
    mutable std::mutex mutex;
    std::condition_variable cv;
    std::atomic<bool> should_stop{false};
    std::thread::id thread_id;
    std::atomic<int> cpu_core{-1};
    std::function<void()> initialization;
    std::function<void()> teardown;
  };

  std::vector<ThreadContext> thread_contexts;
  std::vector<std::jthread> workers;
  std::priority_queue<std::shared_ptr<PrioritizedTask>,
                      std::vector<std::shared_ptr<PrioritizedTask>>,
                      TaskComparator>
      global_queue;
  mutable std::mutex queue_mutex;
  std::condition_variable queue_condition;
  std::vector<std::deque<PrioritizedTask>> worker_queues;
  std::vector<std::mutex> worker_mutexes;
  DependencyGraph dependency_graph;
  std::atomic<bool> is_active;
  std::unordered_map<std::thread::id, std::string> thread_names;
  std::atomic<size_t> total_tasks_executed{0};
  std::atomic<size_t> idle_thread_count{0};
  std::atomic<size_t> pending_task_count{0};
  std::atomic<uint64_t> total_execution_time_us{0};
  std::condition_variable tasks_completed_condition;
  std::function<void(const TaskMetadata &)> on_task_complete;
  std::function<void(std::exception_ptr, const TaskMetadata &)> on_task_error;
  std::atomic<uint64_t> next_task_id{0};
  std::chrono::steady_clock::time_point last_task_submission_time;
  std::atomic<bool> submission_in_progress{false};

  static bool set_thread_affinity(int cpu_core) {
    if (cpu_core < 0) return true;

#if THREADPOOL_WINDOWS
    DWORD_PTR mask = 1ull << cpu_core;
    return SetThreadAffinityMask(GetCurrentThread(), mask) != 0;
#elif THREADPOOL_POSIX
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(cpu_core, &cpuset);
    return pthread_setaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset) ==
           0;
#else
    return false;
#endif
  }

  static int get_processor_count() {
#if THREADPOOL_WINDOWS
    SYSTEM_INFO sysinfo;
    GetSystemInfo(&sysinfo);
    return sysinfo.dwNumberOfProcessors;
#elif THREADPOOL_POSIX
    return sysconf(_SC_NPROCESSORS_ONLN);
#else
    return std::thread::hardware_concurrency();
#endif
  }

  void apply_thread_settings(size_t worker_index) {
    auto &context = thread_contexts[worker_index];
    const int cpu_core = context.cpu_core.load();

    if (cpu_core >= 0) {
      if (!set_thread_affinity(cpu_core)) {
        log_error(
            "Failed to set thread affinity to core " + std::to_string(cpu_core),
            TaskMetadata{});
      }
    }
  }

  bool try_get_local_task(PrioritizedTask &task, size_t worker_id) {
    std::scoped_lock lock(worker_mutexes[worker_id]);
    if (!worker_queues[worker_id].empty()) {
      task = std::move(worker_queues[worker_id].front());
      worker_queues[worker_id].pop_front();
      return true;
    }
    return false;
  }

  bool try_get_global_task(PrioritizedTask &task) {
    std::scoped_lock lock(queue_mutex);
    if (!global_queue.empty()) {
      auto task_ptr = global_queue.top();
      global_queue.pop();
      task = PrioritizedTask(task_ptr->priority, std::move(task_ptr->task),
                             std::move(task_ptr->metadata),
                             std::move(task_ptr->cancelled));
      return true;
    }
    return false;
  }

bool try_steal_work(PrioritizedTask &task, size_t worker_id) {
    // 1. Try stealing from other workers' queues
    for (size_t i = 0; i < worker_queues.size(); ++i) {
      if (i == worker_id) continue;

      std::unique_lock lock(worker_mutexes[i], std::try_to_lock);
      if (!lock.owns_lock()) continue;

      if (!worker_queues[i].empty()) {
        task = std::move(worker_queues[i].back());
        worker_queues[i].pop_back();
        return true;
      }
    }

    // 2. Try getting dependency tasks
    if (auto dep_task = dependency_graph.try_get_ready_task()) {
      auto metadata = std::make_shared<TaskMetadata>();
      metadata->submission_time = std::chrono::steady_clock::now();
      task = PrioritizedTask{PriorityType{}, std::move(*dep_task), metadata,
                             std::make_shared<std::atomic<bool>>(false)};
      return true;
    }

    // 3. Try global queue as last resort
    std::unique_lock global_lock(queue_mutex, std::try_to_lock);
    if (global_lock.owns_lock() && !global_queue.empty()) {
      auto task_ptr = global_queue.top();
      global_queue.pop();
      task = PrioritizedTask{task_ptr->priority, std::move(task_ptr->task),
                             std::move(task_ptr->metadata),
                             std::move(task_ptr->cancelled)};
      return true;
    }

    return false;
  }

  void execute_task(PrioritizedTask &task, size_t worker_id) {
    idle_thread_count.fetch_sub(1, std::memory_order_relaxed);
    auto start_time = std::chrono::steady_clock::now();

    try {
      if (task.metadata) {
        task.metadata->worker_thread_id = thread_contexts[worker_id].thread_id;
        task.metadata->start_time = start_time;
      }

      task.task();  // Execute the task

      if (task.metadata) {
        task.metadata->completion_time = std::chrono::steady_clock::now();
        if (on_task_complete) {
          on_task_complete(*task.metadata);
        }
      }
    } catch (...) {
      if (task.metadata) {
        task.metadata->completion_time = std::chrono::steady_clock::now();
        if (on_task_error) {
          on_task_error(std::current_exception(), *task.metadata);
        } else {
          try {
            std::rethrow_exception(std::current_exception());
          } catch (const std::exception &e) {
            log_error("Exception in worker thread: " + std::string(e.what()),
                      *task.metadata);
          } catch (...) {
            log_error("Unknown exception in worker thread", *task.metadata);
          }
        }
      }
    }

    // Update statistics
    const auto end_time = std::chrono::steady_clock::now();
    const auto duration = std::chrono::duration_cast<std::chrono::microseconds>(
        end_time - start_time);
    total_execution_time_us.fetch_add(duration.count());
    total_tasks_executed.fetch_add(1);
    idle_thread_count.fetch_add(1, std::memory_order_relaxed);

    // Notify task completion
    const auto prev_count =
        pending_task_count.fetch_sub(1, std::memory_order_release);
    if (prev_count == 1) {
      std::scoped_lock lock(queue_mutex);
      tasks_completed_condition.notify_all();
    }

    // Update CPU core affinity
    if (thread_contexts[worker_id].cpu_core.load() != -1) {
      thread_local int last_core = -1;
      int current_core = thread_contexts[worker_id].cpu_core.load();
      if (current_core != last_core) {
        apply_thread_settings(worker_id);
        last_core = current_core;
      }
    }
  }

void worker_loop(const std::stop_token& stop_token, size_t worker_id) {
    // Initialize worker thread
    auto &context = thread_contexts[worker_id];
    context.thread_id = std::this_thread::get_id();

    // Set thread name
    const std::string name = "worker_" + std::to_string(worker_id);
    set_thread_name(context.thread_id, name);

    // Apply thread settings (affinity, etc.)
    apply_thread_settings(worker_id);

    // Run thread initialization callback if provided
    if (context.initialization) {
      try {
        context.initialization();
      } catch (...) {
        log_error("Thread initialization failed", TaskMetadata{});
      }
    }

    // Main work loop
    while (!stop_token.stop_requested() && is_active.load()) {
      PrioritizedTask task;
      bool task_executed = false;

      // Attempt to get a task with exponential backoff
      for (int attempt = 0; attempt < 4 && !task_executed; ++attempt) {
        // 1. FIRST PRIORITY: Check local queue
        if (try_get_local_task(task, worker_id)) {
          execute_task(task, worker_id);
          task_executed = true;
          break;
        }

        // 2. SECOND PRIORITY: Try to steal work (includes dependency tasks)
        if (try_steal_work(task, worker_id)) {
          execute_task(task, worker_id);
          task_executed = true;
          break;
        }

        // Exponential backoff if no task found
        if (!task_executed && attempt < 3) {
          std::this_thread::sleep_for(std::chrono::milliseconds(1 << attempt));
        }
      }

      // If no tasks were found after all attempts, wait with conditions
      if (!task_executed) {
        std::unique_lock lock(thread_contexts[worker_id].mutex);
        idle_thread_count.fetch_add(1, std::memory_order_relaxed);

        // Wait for:
        // 1. New task in local queue
        // 2. Stop request
        // 3. Any work that might be stealable
        thread_contexts[worker_id].cv.wait_for(
            lock, std::chrono::milliseconds(100), [&] {
              return !thread_contexts[worker_id].queue.empty() ||
                     stop_token.stop_requested() ||
                     dependency_graph.has_ready_task() || !global_queue.empty();
            });

        idle_thread_count.fetch_sub(1, std::memory_order_relaxed);
      }
    }

    // Thread teardown
    if (context.teardown) {
      try {
        context.teardown();
      } catch (...) {
        log_error("Thread teardown failed", TaskMetadata{});
      }
    }
  }

  void dispatch_to_thread(size_t worker_index, std::function<void()> f) {
    if (auto &context = thread_contexts[worker_index]; std::this_thread::get_id() == context.thread_id) {
      f();
    } else {
      std::packaged_task<void()> task(f);
      {
        std::scoped_lock lock(context.mutex);
        context.queue.push_front(
            PrioritizedTask{std::numeric_limits<PriorityType>::max(),
                            std::move(task), nullptr, nullptr});
      }
      context.cv.notify_one();
    }
  }

  static void log_error(const std::string &message,
                        const TaskMetadata &metadata) {
    std::cerr << "[ThreadPool Error] Thread " << std::this_thread::get_id()
              << " in task " << metadata.name << ": " << message << std::endl;
  }

 public:
  thread_pool(const thread_pool &) = delete;
  thread_pool &operator=(const thread_pool &) = delete;

  explicit thread_pool(size_t thread_count)
      : thread_contexts(thread_count),
        worker_queues(thread_count),
        worker_mutexes(thread_count),
        is_active(true),
        idle_thread_count(thread_count) {
    for (auto &context : thread_contexts) {
      context.should_stop.store(false);
    }

    for (size_t i = 0; i < thread_count; ++i) {
      workers.emplace_back([this, i](std::stop_token stop_token) {
        worker_loop(stop_token, i);
      });
    }
  }

  ~thread_pool() {
    shutdown();
    wait_for_tasks();
  }

  template <typename F, typename... Args>
auto submit(PriorityType priority,
            std::chrono::steady_clock::duration timeout,
            F&& f,
            Args&&... args)
    -> std::pair<std::future<typename std::invoke_result<F, Args...>::type>,
                 TaskHandle> {
    using return_type = typename std::invoke_result<F, Args...>::type;

    submission_in_progress.store(true);
    last_task_submission_time = std::chrono::steady_clock::now();
    auto cancelled = std::make_shared<std::atomic<bool>>(false);
    auto metadata = std::make_shared<TaskMetadata>();
    metadata->submission_time = std::chrono::steady_clock::now();
    metadata->name = "task_" + std::to_string(next_task_id.fetch_add(1));
    metadata->timeout = timeout;

    std::packaged_task<return_type()> packaged_task(
        [cancelled, f = std::forward<F>(f), args...]() {
          if (cancelled->load()) throw task_cancelled_error();
          return f(args...);
        });

    std::future<return_type> result = packaged_task.get_future();

    auto wrapped_task = std::packaged_task<void()>(
        [packaged_task = std::move(packaged_task), metadata]() mutable {
          auto future = packaged_task.get_future();
          metadata->start_time = std::chrono::steady_clock::now();
          try {
            if (metadata->timeout.has_value()) {
              if (future.wait_for(metadata->timeout.value()) ==
                  std::future_status::timeout) {
                throw std::runtime_error("Task timed out");
              }
            }
            packaged_task();
          } catch (...) {
            metadata->completion_time = std::chrono::steady_clock::now();
            throw;
          }
          metadata->completion_time = std::chrono::steady_clock::now();
        });

    TaskHandle handle{cancelled, metadata, next_task_id.load()};
    {
      std::scoped_lock lock(queue_mutex);
      auto task_ptr = std::make_shared<PrioritizedTask>(
          priority, std::move(wrapped_task), metadata, cancelled);
      global_queue.push(task_ptr);
      pending_task_count.fetch_add(1, std::memory_order_relaxed);
    }

    queue_condition.notify_one();
    submission_in_progress.store(false);
    return {std::move(result), std::move(handle)};
  }

  template <typename F, typename... Args>
  auto submit(PriorityType priority, F &&f, Args &&...args)
      -> std::pair<std::future<std::invoke_result_t<F, Args...>>, TaskHandle> {
    return submit(priority, std::chrono::steady_clock::duration::max(),
                  std::forward<F>(f), std::forward<Args>(args)...);
  }

  template <typename F, typename... Args>
  auto submit_with_dependencies(PriorityType priority,
                                std::chrono::steady_clock::duration timeout,
                                const std::vector<TaskHandle> &dependencies,
                                F &&f, Args &&...args)
      -> std::pair<std::future<typename std::invoke_result_t<F, Args...>>,
                   TaskHandle> {
    using return_type = typename std::invoke_result_t<F, Args...>;

    {
      std::scoped_lock lock(queue_mutex);
      for (const auto &dep : dependencies) {
        if (dependency_graph.has_cycle()) {
          throw std::runtime_error("Circular dependency detected");
        }
      }
    }

    auto cancelled = std::make_shared<std::atomic<bool>>(false);
    auto metadata = std::make_shared<TaskMetadata>();
    metadata->submission_time = std::chrono::steady_clock::now();
    metadata->name = "task_" + std::to_string(next_task_id.fetch_add(1));
    metadata->timeout = timeout;

    auto task = std::make_shared<std::packaged_task<return_type()>>(
        [cancelled, func = std::forward<F>(f),
         args_tuple = std::make_tuple(std::forward<Args>(args)...)]() {
          if (cancelled->load()) throw task_cancelled_error();
          return std::apply(func, args_tuple);
        });

    std::future<return_type> result = task->get_future();

    auto packaged_task = std::packaged_task<void()>(
        [task, metadata, id = next_task_id.load(), this,
         result_future = std::move(result)]() mutable {
          metadata->start_time = std::chrono::steady_clock::now();
          metadata->worker_thread_id = std::this_thread::get_id();
          try {
            if (metadata->timeout.has_value()) {
              const auto &timeout_value = metadata->timeout.value();
              if (result_future.wait_for(timeout_value) ==
                  std::future_status::timeout) {
                throw std::runtime_error("Task timed out");
              }
            }
            task->operator()();
          } catch (...) {
            metadata->completion_time = std::chrono::steady_clock::now();
            throw;
          }
          metadata->completion_time = std::chrono::steady_clock::now();
          dependency_graph.mark_completed(id);
          pending_task_count.fetch_sub(1, std::memory_order_relaxed);
          if (pending_task_count.load() == 0) {
            tasks_completed_condition.notify_all();
          }
        });

    TaskHandle handle{cancelled, metadata, next_task_id.load()};
    {
      std::scoped_lock lock(queue_mutex);
      dependency_graph.add_task(std::move(packaged_task), *metadata,
                                dependencies);
      pending_task_count.fetch_add(1, std::memory_order_relaxed);
    }

    queue_condition.notify_one();
    return {std::move(result), std::move(handle)};
  }

  template <typename F, typename... Args>
  auto submit_with_dependencies(PriorityType priority,
                                const std::vector<TaskHandle> &dependencies,
                                F &&f, Args &&...args)
      -> std::pair<std::future<std::invoke_result_t<F, Args...>>, TaskHandle> {
    return submit_with_dependencies(
        priority, std::chrono::steady_clock::duration::max(), dependencies,
        std::forward<F>(f), std::forward<Args>(args)...);
  }

  template <typename Func>
  auto submit_batch(PriorityType priority,
                    std::chrono::steady_clock::duration timeout,
                    std::vector<Func> tasks)
      -> std::vector<
          std::pair<std::future<std::invoke_result_t<Func>>, TaskHandle>> {
    std::vector<std::pair<std::future<std::invoke_result_t<Func>>, TaskHandle>>
        handles;
    for (auto &task_func : tasks) {
      handles.push_back(submit(priority, timeout, std::move(task_func)));
    }
    return handles;
  }

  template <typename Func>
  auto submit_batch(PriorityType priority, std::vector<Func> tasks)
      -> std::vector<
          std::pair<std::future<std::invoke_result_t<Func>>, TaskHandle>> {
    std::vector<std::pair<std::future<std::invoke_result_t<Func>>, TaskHandle>>
        handles;
    handles.reserve(tasks.size());
for (auto &task_func : tasks) {
      handles.push_back(submit(priority, std::move(task_func)));
    }
    return handles;
  }


  void wait_for_tasks(
      std::chrono::milliseconds timeout = std::chrono::seconds(30)) {
    const auto start = std::chrono::steady_clock::now();
    bool warning_printed = false;

    while (true) {
      // 1. First try to help process tasks if we're nearing timeout
      if (std::chrono::steady_clock::now() - start > timeout / 2) {
        if (!warning_printed) {
          std::cerr << "Warning: Tasks taking longer than expected...\n";
          warning_printed = true;
          debug_check_state();
        }

        if (emergency_process_blocked_tasks(true)) {
          continue;
        }

        // Main thread helps process dependency tasks
        if (auto dep_task = dependency_graph.try_get_ready_task()) {
          auto metadata = std::make_shared<TaskMetadata>();
          metadata->submission_time = std::chrono::steady_clock::now();
          PrioritizedTask task{PriorityType{}, std::move(*dep_task), metadata,
                               std::make_shared<std::atomic<bool>>(false)};
          execute_task(task, 0);  // Execute in main thread
          continue;
        }
      }

      // 2. Check completion conditions
      {
        std::unique_lock lock(queue_mutex);
        if (pending_task_count.load() == 0 &&
            dependency_graph.pending_count() == 0) {
          return;
        }
      }

      // 3. Normal wait
      {
        std::unique_lock lock(queue_mutex);
        const bool completed = tasks_completed_condition.wait_for(
            lock, std::chrono::milliseconds(100), [this] {
              return pending_task_count.load() == 0 &&
                     dependency_graph.pending_count() == 0;
            });

        if (completed) {
          return;
        }
      }

      // 4. Timeout check
     if (std::chrono::steady_clock::now() - start > timeout) {
        emergency_process_blocked_tasks(true);  // Forceful recovery

        std::stringstream ss;
        ss << "Timeout waiting for tasks (" << timeout.count() << "ms)\n";
        ss << "Pending tasks: " << pending_task_count.load() << "\n";
        ss << "Dependency tasks: " << dependency_graph.pending_count() << "\n";

        throw std::runtime_error(ss.str());

      }
    }
  }

  void debug_check_state() {
    std::scoped_lock lock(queue_mutex);

    std::cout << "=== Thread Pool State ===\n";
    std::cout << "Pending tasks: " << pending_task_count.load() << "\n";
    std::cout << "Idle workers: " << idle_thread_count.load() << "/"
              << workers.size() << "\n";
    std::cout << "Dependency tasks: " << dependency_graph.pending_count()
              << "\n";
    std::cout << "Global queue size: " << global_queue.size() << "\n";

    for (size_t i = 0; i < workers.size(); ++i) {
      std::scoped_lock ctx_lock(thread_contexts[i].mutex);
      std::cout << "Worker " << i << " (" << thread_contexts[i].thread_id
                << "): " << (thread_contexts[i].queue.empty() ? "idle" : "busy")
                << "\n";
    }

    // Check dependencies
    dependency_graph.debug_print();
  }

  void check_for_deadlock() {
    const auto now = std::chrono::steady_clock::now();
    std::scoped_lock lock(queue_mutex);

    if (pending_task_count > 0 && idle_thread_count == workers.size() &&
        now - last_task_submission_time > std::chrono::seconds(5)) {
      // Gather diagnostic information
      std::stringstream ss;
      ss << "DEADLOCK DETECTED!\n";
      ss << "Pending tasks: " << pending_task_count << "\n";
      ss << "Idle workers: " << idle_thread_count << "/" << workers.size()
         << "\n";
      ss << "Dependency tasks: " << dependency_graph.pending_count() << "\n";

      // Forcefully unlock tasks
      emergency_task_unlock();

      throw std::runtime_error(ss.str());
    }
  }

  bool emergency_process_blocked_tasks(bool force) {
    bool processed = dependency_graph.emergency_process_blocked_tasks(force);

    // Process any tasks that became ready
    while (auto task = dependency_graph.try_get_ready_task()) {
      auto metadata = std::make_shared<TaskMetadata>();
      metadata->submission_time = std::chrono::steady_clock::now();
      PrioritizedTask ptask{PriorityType{}, std::move(*task), metadata,
                            std::make_shared<std::atomic<bool>>(false)};
      execute_task(ptask, 0);  // Execute in current thread
      processed = true;
    }

    return processed;
  }
  void emergency_task_unlock() {
    // Unlock all ready tasks in the dependency graph
    while (auto dep_task = dependency_graph.try_get_ready_task()) {
      auto metadata = std::make_shared<TaskMetadata>();
      metadata->submission_time = std::chrono::steady_clock::now();
      PrioritizedTask task = PrioritizedTask{
        PriorityType{}, std::move(*dep_task), metadata,
        std::make_shared<std::atomic<bool> >(false)
      };
      execute_task(task, 0);  // Execute in current thread
    }

    // Reset counters
    pending_task_count.store(0);
  }

  void shutdown() {
    is_active.store(false);
    queue_condition.notify_all();
    tasks_completed_condition.notify_all();
    for (auto &worker : workers) {
      if (worker.joinable()) {
        worker.request_stop();
        worker.join();
      }
    }
  }

  void emergency_shutdown() {
    is_active.store(false);

    {
      std::scoped_lock lock(queue_mutex);
      while (!global_queue.empty()) {
        global_queue.pop();
      }
      pending_task_count.store(0);
    }

    dependency_graph.clear_all();

    queue_condition.notify_all();
    tasks_completed_condition.notify_all();

    for (auto &worker : workers) {
      if (worker.joinable()) {
        worker.request_stop();
        worker.join();
      }
    }
  }

  static void log_task_submission(const TaskHandle &handle) {
    std::string tags_str;
    for (const auto &tag : handle.metadata->tags) {
      if (!tags_str.empty()) tags_str += ", ";
      tags_str += tag;
    }

    std::cout << "Submitted task " << handle.task_id << " tags: " << tags_str
              << " priority: "
              << handle.metadata->priority
                     .value_or(std::chrono::steady_clock::duration::zero())
                     .count()
              << " name: " << handle.metadata->name << "\n";
  }

  static void log_task_start(const TaskMetadata &meta) {
    std::cout << "Started task " << meta.name << " on thread "
              << meta.worker_thread_id << "\n";
  }

  static void log_task_state(const TaskMetadata &meta) {
    std::cout << "Task " << meta.name << " deps=" << meta.dependencies.size()
              << " status=" << (meta.completion_time ? "done" : "pending")
              << std::endl;
  }

  static void wait_for_dependencies(const std::vector<TaskHandle> &deps,
                             const std::chrono::milliseconds timeout) {
    const auto start = std::chrono::steady_clock::now();
    for (const auto &dep : deps) {
      while (!dep.is_ready()) {
        if (std::chrono::steady_clock::now() - start > timeout) {
          throw std::runtime_error("Dependency timeout");
        }
        std::this_thread::yield();
      }
    }
  }

  static void verify_dependencies(const std::vector<TaskHandle> &deps) {
    for (const auto &dep : deps) {
      if (dep.cancelled->load()) {
        throw std::runtime_error("Dependency task " +
                                 std::to_string(dep.task_id) + " is cancelled");
      }
    }
  }

  static void cancel_task(const TaskHandle &handle) {
    if (handle.cancelled) {
      handle.cancelled->store(true);
    }
  }

  void configure_thread(size_t worker_index, int cpu_core = -1,
                        std::function<void()> init = nullptr,
                        std::function<void()> cleanup = nullptr) {
    if (worker_index >= workers.size()) return;

    auto &context = thread_contexts[worker_index];
    context.cpu_core.store(cpu_core);
    context.initialization = init;
    context.teardown = cleanup;

    if (cpu_core >= 0) {
      if (const int max_cores = get_processor_count(); cpu_core >= max_cores) {
        log_error("Invalid CPU core in configure_thread - max is " +
                      std::to_string(max_cores - 1),
                  TaskMetadata{});
        context.cpu_core.store(-1);
      }
    }

    if (context.thread_id != std::thread::id()) {
      dispatch_to_thread(worker_index, [this, worker_index] {
        apply_thread_settings(worker_index);
      });
    }
  }

  struct ThreadPoolStats {
    size_t tasks_executed;
    size_t tasks_pending;
    size_t threads_active;
    size_t threads_idle;
    std::chrono::microseconds total_cpu_time;
    size_t dependency_tasks_pending;
  };

  ThreadPoolStats get_stats() const {
    std::scoped_lock lock(queue_mutex);
    return {total_tasks_executed.load(std::memory_order_relaxed),
            global_queue.size(),
            workers.size() - idle_thread_count.load(std::memory_order_relaxed),
            idle_thread_count.load(std::memory_order_relaxed),
            std::chrono::microseconds(
                total_execution_time_us.load(std::memory_order_relaxed)),
            dependency_graph.pending_count()};
  }

  void set_on_task_complete_callback(
      std::function<void(const TaskMetadata &)> callback) {
    on_task_complete = std::move(callback);
  }

  void set_on_task_error_callback(
      std::function<void(std::exception_ptr, const TaskMetadata &)> callback) {
    on_task_error = std::move(callback);
  }

  std::string get_thread_name(std::thread::id id) const {
    auto it = thread_names.find(id);
    return it != thread_names.end() ? it->second : "";
  }

  void set_thread_name(std::thread::id id, const std::string &name) {
    thread_names[id] = name;
  }

  void reset_statistics() {
    total_tasks_executed.store(0);
    total_execution_time_us.store(0);
  }


};

template<typename PriorityType>
thread_pool<PriorityType>::PrioritizedTask::PrioritizedTask() = default;
}  // namespace thread_pool


int main() {
  // Create thread pool with 4 threads
  thread_pool::thread_pool<int> pool(4);

  // Set up error handler for all tasks
  pool.set_on_task_error_callback(
      [](const std::exception_ptr &eptr, const thread_pool::TaskMetadata& metadata) {
        try {
          if (eptr) std::rethrow_exception(eptr);
        } catch (const std::exception& e) {
          std::cerr << "Error in task " << metadata.name << ": " << e.what()
                    << std::endl;
        }
      });

  // Check initial stats
  auto stats1 = pool.get_stats();
  std::cout << "Initial stats - Idle threads: " << stats1.threads_idle << "\n";

  // Example 1: Simple task submission
  auto [task1_future, task1_handle] =
      pool.submit(1,  // priority
                  []() {
                    std::cout << "Task 1 running on thread "
                              << std::this_thread::get_id() << std::endl;
                    std::this_thread::sleep_for(std::chrono::seconds(1));
                    return 42;
                  });

  // Example 2: Tasks with dependencies
  std::vector<thread_pool::TaskHandle> dependencies;

  // Dependency 1
  auto [dep1_future, dep1_handle] = pool.submit(1, []() {
    std::cout << "Dependency 1 running on thread " << std::this_thread::get_id()
              << std::endl;
    std::this_thread::sleep_for(std::chrono::milliseconds(500));
    return 10;
  });
  dependencies.push_back(dep1_handle);

  // Dependency 2
  auto [dep2_future, dep2_handle] = pool.submit(1, []() {
    std::cout << "Dependency 2 running on thread " << std::this_thread::get_id()
              << std::endl;
    std::this_thread::sleep_for(std::chrono::milliseconds(700));
    return 20;
  });
  dependencies.push_back(dep2_handle);

  // Task depending on dep1 and dep2
  auto [task2_future, task2_handle] = pool.submit_with_dependencies(
      2,  // higher priority
      dependencies, [&dep1_future, &dep2_future]() {
        std::cout << "Task 2 running on thread " << std::this_thread::get_id()
                  << std::endl;
        int result1 = dep1_future.get();
        int result2 = dep2_future.get();
        return result1 + result2;
      });

  // Example 3: Batch task submission
  std::vector<std::function<int()>> batch_tasks;
  for (int i = 0; i < 5; ++i) {
    batch_tasks.emplace_back([i]() {
      std::cout << "Batch task " << i << " running on thread "
                << std::this_thread::get_id() << std::endl;
      std::this_thread::sleep_for(std::chrono::milliseconds(200));
      return i * 2;
    });
  }

  auto batch_results = pool.submit_batch(3, batch_tasks);

  // Debug check and wait
  pool.debug_check_state();
  pool.wait_for_tasks();

  // Get results
  try {
    std::cout << "Task 1 result: " << task1_future.get() << std::endl;
    std::cout << "Task 2 result: " << task2_future.get() << std::endl;

    std::cout << "Batch task results: ";
    for (auto& [future, handle] : batch_results) {
      std::cout << future.get() << " ";
    }
    std::cout << std::endl;
  } catch (const std::exception& e) {
    std::cerr << "Error getting results: " << e.what() << std::endl;
  }

  // Final stats
  auto stats = pool.get_stats();
  std::cout << "\nThreadPool Stats:" << std::endl;
  std::cout << "  Tasks Executed: " << stats.tasks_executed << std::endl;
  std::cout << "  Tasks Pending: " << stats.tasks_pending << std::endl;
  std::cout << "  Threads Active: " << stats.threads_active << std::endl;
  std::cout << "  Threads Idle: " << stats.threads_idle << std::endl;
  std::cout << "  Total CPU Time: " << stats.total_cpu_time.count() << " us"
            << std::endl;
  std::cout << "  Dependency Tasks Pending: " << stats.dependency_tasks_pending
            << std::endl;

  return 0;
}
