#!/bin/bash
# Налаштування детального логування виводу скрипта для трасування
exec > >(tee -a /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
echo "[ІНФО] Початок виконання user_data скрипта - $(date)"

# 1. Ідемпотентне встановлення Apache2
if ! command -v apache2 &> /dev/null; then
  echo "[ІНФО] Встановлення вебсервера Apache2..."
  apt-get update -y
  apt-get install -y apache2
else
  echo "[ІНФО] Apache2 вже встановлений. Пропуск кроку."
fi

# 2. Налаштування кастомного TCP порту (згідно з варіантом)
echo "[ІНФО] Зміна порту прослуховування на ${WEB_PORT}..."
sed -i "s/Listen 80/Listen ${WEB_PORT}/" /etc/apache2/ports.conf

# 3. Створення та конфігурація DocumentRoot
echo "[ІНФО] Створення цільової директорії ${DOC_ROOT}..."
mkdir -p ${DOC_ROOT}

# Створення індексної HTML сторінки
cat <<EOF > ${DOC_ROOT}/index.html
<!DOCTYPE html>
<html lang="uk">
  <head>
    <meta charset="utf-8">
    <title>Лабораторна робота №3 - IaC Terraform</title>
    <style>
      body {
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        background-color: #e9ecef;
        color: #495057;
        text-align: center;
        padding-top: 10vh;
      }
      .container {
        background: white;
        padding: 40px;
        border-radius: 12px;
        box-shadow: 0 10px 20px rgba(0,0,0,0.1);
        display: inline-block;
        max-width: 600px;
        width: 100%;
      }
      h1 {
        color: #5c6bc0;
        font-size: 24px;
        margin-bottom: 20px;
      }
      p {
        font-size: 16px;
        margin: 10px 0;
        text-align: left;
        border-bottom: 1px solid #f1f3f5;
        padding-bottom: 5px;
      }
      .footer {
        margin-top: 30px;
        font-size: 12px;
        color: #adb5bd;
      }
    </style>
  </head>
  <body>
    <div class="container">
      <h1>AWS Інфраструктура успішно розгорнута (Terraform)</h1>
      <p><strong>Студент/Префікс:</strong> ${STUDENT}</p>
      <p><strong>Віртуальний хост (Server Name):</strong> ${SERVER_NAME}</p>
      <p><strong>Шлях до Document Root:</strong> ${DOC_ROOT}</p>
      <p><strong>Активний порт:</strong> ${WEB_PORT}</p>
      <div class="footer">Час генерації сторінки: $(date)</div>
    </div>
  </body>
</html>
EOF

# Надання прав доступу системному користувачу Apache
chown -R www-data:www-data ${DOC_ROOT}
chmod -R 755 ${DOC_ROOT}

# 4. Налаштування віртуального хосту (VirtualHost)
VHOST_CONF="/etc/apache2/sites-available/custom-site.conf"
cat <<'APACHEVHOST' > $VHOST_CONF
<VirtualHost *:${WEB_PORT}>
ServerName ${SERVER_NAME}
DocumentRoot ${DOC_ROOT}
AddDefaultCharset utf-8
ErrorLog $${APACHE_LOG_DIR}/custom_error.log
CustomLog $${APACHE_LOG_DIR}/custom_access.log combined
</VirtualHost>
APACHEVHOST

# 5. Модифікація глобальної конфігурації для запобігання помилки '403 Forbidden'
# Якщо директорія не стандартна, Apache блокує доступ згідно політик безпеки
if ! grep -q "<Directory ${DOC_ROOT}>" /etc/apache2/apache2.conf; then
  echo "[ІНФО] Додавання дозволів на директорію в apache2.conf..."
  cat <<EOF >> /etc/apache2/apache2.conf
<Directory ${DOC_ROOT}>
Options Indexes FollowSymLinks
AllowOverride None
Require all granted
</Directory>
EOF
fi

# 6. Активація змін та перезапуск служби
echo "[ІНФО] Активація сайту та перезапуск сервісу..."
a2dissite 000-default.conf
a2ensite custom-site.conf
systemctl restart apache2
systemctl enable apache2
echo "[ІНФО] Ініціалізацію успішно завершено - $(date)"
