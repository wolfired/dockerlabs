$ORIGIN wolfired.com.
@       3600 IN SOA  ns1.wolfired.com. admin.wolfired.com. (
                    2024010101 ; serial
                    3600       ; refresh
                    900        ; retry
                    604800     ; expire
                    86400     ; minimum TTL
                )

; DNS 服务器
@       IN NS     ns1.wolfired.com.
ns1     IN A      192.168.100.168

; 邮件服务器
mail    IN A      192.168.100.168
smtp    IN A      192.168.100.168
imap    IN A      192.168.100.168

; MX 记录
@       IN MX 10  mail.wolfired.com.

; 其他记录
;www     IN A      192.168.100.168
;ftp     IN CNAME  www.wolfired.com.
@       IN TXT    "v=spf1 a mx ~all"  ; SPF 反垃圾邮件
_dmarc  IN TXT    "v=DMARC1; p=none; rua=mailto:admin@wolfired.com"
