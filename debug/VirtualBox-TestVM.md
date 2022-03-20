## Create VM
```shell
VBoxManage createvm --name "TestVM" --register

VBoxManage modifyvm  "TestVM" --cpus 1
VBoxManage modifyvm  "TestVM" --memory 512
VBoxManage modifyvm  "TestVM" --acpi on
VBoxManage modifyvm  "TestVM" --graphicscontroller vmsvga
VBoxManage modifyvm  "TestVM" --vram 1
VBoxManage modifyvm  "TestVM" --accelerate3d off
VBoxManage modifyvm  "TestVM" --audio none
VBoxManage modifyvm  "TestVM" --nic1 nat

VBoxManage storagectl "TestVM" --name "Floppy Controller" --add floppy
VBoxManage storageattach "TestVM" --storagectl "Floppy Controller" --port 0 --device 0 --type fdd --medium "~/ipxe/src/bin/ipxe.dsk"

VBoxManage modifyvm "TestVM" --boot1 floppy

VBoxManage modifyvm "TestVM" --vrde on
VBoxManage modifyvm "TestVM" --vrdeproperty VNCPassword=xxxxxxxxxxxx
VBoxManage modifyvm "TestVM" --vrdeaddress=0.0.0.0
VBoxManage modifyvm "TestVM" --vrdeport 5900

VBoxManage startvm "TestVM" --type headless

VBoxManage controlvm "TestVM" poweroff
```
