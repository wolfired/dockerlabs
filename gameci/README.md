## gameci

```bash

sudo docker run -it --rm --network lanet --ip 192.168.1.200 --dns 192.168.1.2 unityci/editor:ubuntu-2021.2.7f1-windows-mono-0.15.0 bash
sudo docker-compose run --rm builder bash

git config --global http.sslVerify false

git clone https://gitea.wolfired.com/wolfired/u3d_test001.git

unity-editor -createManualActivationFile
unity-editor -logFile - -manualLicenseFile /gameci/u3d_test001/Unity_v2021.x.ulf

-buildWindowsPlayer

unity-editor -logFile - -quit -batchmode -projectPath /gameci/u3d_test001 -buildTarget Win -executeMethod Main.Test

```