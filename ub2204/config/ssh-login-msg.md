
dir /etc/update-motd.d/

```
sed 's|ENABLED=1|ENABLED=0|g' -i /etc/default/motd-news
```
remove
```

 * Ubuntu Pro delivers the most comprehensive open source security and
   compliance features.

   https://ubuntu.com/aws/pro
```
