#include <QApplication>
#include <QFile>
#include <QTimer>
#include <QWidget>

#include "ui_window.h"

class Window final : public QWidget {
  Q_OBJECT

 public:
  Window() {
    ui_.setupUi(this);
    QFile message(QStringLiteral(":/qt/message.txt"));
    if (message.open(QIODevice::ReadOnly)) {
      ui_.message->setText(QString::fromUtf8(message.readAll()).trimmed());
    }
  }

  bool ready() const {
    return ui_.message->text() == QStringLiteral("Qt 6 is ready") &&
           QString::fromLatin1(metaObject()->className()) ==
               QStringLiteral("Window");
  }

 private:
  Ui::Window ui_;
};

int main(int argc, char **argv) {
  QApplication app(argc, argv);
  Window window;
  if (!window.ready()) {
    return 1;
  }
  window.show();
  if (app.arguments().contains(QStringLiteral("--smoke"))) {
    QTimer::singleShot(0, &app, &QCoreApplication::quit);
  }
  return app.exec();
}

#include "main.moc"
