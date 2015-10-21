![](https://raw.githubusercontent.com/igorpecovnik/hostapd/master/bin/hostapd.png)

This is a script to compile, patch and pack hostapd deamon. It can be used as a drop-in replacement for Debian and Ubuntu based distributions.

You can choose between development and stable version but you always get those two patches on the top:

- option to control HT coexistance separate from noscan (to force 40Mhz channels)
- driver interface for rtl871x driver (to use with some realtek adapters)

```bash
sudo apt-get -y install git
cd ~
git clone https://github.com/igorpecovnik/hostapd
chmod +x ./hostapd/go.sh
cd hostapd
./go.sh
```
