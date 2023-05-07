<div align="center">
  <h1>RDPShoot</h1>
</div>
<div align="center">
  <img src="https://user-images.githubusercontent.com/67438760/236649071-9bc6c030-7ff0-40c9-8dfd-e4e096f0b30a.png" align="center">
</div>

The purpose of this tool is to capture screenshots of Windows machines with RDP (Remote Desktop Protocol) enabled and NLA (Network Level Authentication) disabled. The tool verifies the availability of the open port and the disabled NLA feature, and proceeds to capture screenshots. It further utilizes Optical Character Recognition (OCR) to transcribe the text in the captured screenshots, and generates a list of users based on the captured images.

<div align="center">
  <h2>Installation</h2>
</div>

Clone the repository and make the script executable:

```bash
git clone https://github.com/shockz-offsec/rdpshoot.git
cd rdpshoot
chmod +x rdpshoot.sh
```

You will also need to install the following dependencies:

```bash
apt-get install xdotool imagemagick rdesktop bc tesseract-ocr nmap python3 python3-pip -y
```

<div align="center">
  <h2>Usage</h2>
</div>

| Only for Linux and MacOS

The tool requires an IP address or IP with CIDR as input. For example:

```bash
./rdpshoot.sh 192.168.1.2
```

or

```bash
./rdpshoot.sh 192.168.1.0/24
```

The output will be saved in a folder named `output` with a timestamp.

<div align="center">
  <h2>Disclaimer</h2>
</div>

This tool is designed for legal use only, such as testing and monitoring of systems that you own or have permission to test. Any other use is illegal and at your own risk. The author is not responsible for any damage caused by misuse or illegal use of this tool.

<div align="center">
  <h2>License</h2>
</div>

This tool is licensed under the GPL-3.0 License.