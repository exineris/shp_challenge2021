# Exibee

## 準備（ExiBee接点の設定）
以下の場合はこのセクションはスキップして、「Nervesの設定」にすすむ。
- `git clone` している場合
- `rootfs_overlay/lib/firmware/ExiBee-IODEF.dtbo` がある場合

準備ができていない場合は、ExiBee-IODEF.dtsを `rootfs_overlay/lib/firmware` に保存する。
### dtboの作成
 `rootfs_overlay/lib/firmware/ExiBee-IODEF.dtbo` ファイルがあればExibeeが動作するのでdtsファイルからdtboファイルを作成する。

```
$ cd rootfs_overlay/lib/firmware/
$ dtc -O dtb -o ExiBee-IODEF.dtbo ExiBee-IODEF.dts
```


## Nervesの設定
```
$ git clone https://github.com/exineris/exibee.git

$ cd exibee
$ mix deps.get
```

`deps/nerves_system_bbb/fwup_include/provisioning.conf` を編集する。
```
（抜粋）
###Additional custom capes
uboot_setenv(uboot-env, "uboot_overlay_addr4", "/lib/firmware/ExiBee-IODEF.dtbo")
```

`mix.exs` を編集する（ `git clone` していると編集済み）。
```
- {:nerves_system_bbb, "~> 2.8", runtime: false, targets: :bbb},
+ {:nerves_system_bbb, "~> 2.8", runtime: false, targets: :bbb, nerves:
[compile: true]},
```

コンパイル（とても時間がかかる）。
```
<fish>
❯ set -x MIX_TARGET bbb

<bash>
$ export MIX_TARGET=bbb

$ mix deps.compile nerves_system_bbb
$ mix firmware
$ mix burn
```

### 確認
NervesをインストールしたExibeeにSSHログイン後、`Circuits.I2C.detect_devices` コマンドを実行した結果、"i2c-1"が確認できていれば設定完了。

```
$ mix upload
$ ssh 192.168.5.55
Interactive Elixir (1.10.3) - press Ctrl+C to exit (type h() ENTER for help)
Toolshed imported. Run h(Toolshed) for more info.
RingLogger is collecting log messages from Elixir and Linux. To see the
messages, either attach the current IEx session to the logger:

  RingLogger.attach

or print the next messages in the log:

  RingLogger.next

iex(1)> Circuits.I2C.detect_devices
Devices on I2C bus "i2c-0":
 * 36  (0x24)
 * 80  (0x50)

Devices on I2C bus "i2c-1":
 * 16  (0x10)
 * 32  (0x20)
 * 85  (0x55)
 * 104  (0x68)

Devices on I2C bus "i2c-2":

7 devices detected on 3 I2C buses
```