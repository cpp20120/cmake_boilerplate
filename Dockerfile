# Используем многоэтапную сборку
FROM fedora:latest AS builder

# Устанавливаем зависимости
RUN dnf install -y dnf5 && \
    dnf5 install -y \
    @development-tools \
    clang clang-tools-extra \
    cmake ninja-build \
    mold lld \
    gtest gtest-devel \
    doxygen \
    glslang spirv-tools && \
    dnf clean all

# Копируем исходники
WORKDIR /project
COPY . .

# Собираем проект
RUN mkdir -p build && cd build && \
    cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release && \
    cmake --build . --parallel $(nproc)

# Финальный образ
FROM fedora:latest

# Устанавливаем только необходимые для работы зависимости
RUN dnf install -y \
    libstdc++ \
    glibc \
    vulkan-loader && \
    dnf clean all

# Копируем собранные бинарники из builder-этапа
COPY --from=builder /project/build/bin/ /usr/local/bin/
COPY --from=builder /project/build/lib/ /usr/local/lib/

# Указываем точку входа
CMD ["/usr/local/bin/test"]