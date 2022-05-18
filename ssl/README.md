## Инструкция по использованию скрипта


#### Получение скрипта
Для начала необходимо залогиниться на на мастере ноде и получить скрипт выполнив команду:

```wget https://raw.githubusercontent.com/ispringtech/on-prem-learn-scripts/main/ssl/ssl-checker.sh -O ssl-checker.sh; chmod +x ssl-checker.sh```

#### Выполнение скрипта
Для выполнения скрипта проверки сертификата необходимо запустить скрипт `ssl-checker.sh` передав путь к сертификату и ключу

```
./ssl-checker.sh <path-to-certificate> <path-to-key>
```

В результате после успешного прохождения проверки SSL сертификата и ключа должны получить примерно следующий вывод:
> SSL certificate and key verified successfully.
