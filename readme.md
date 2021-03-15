#  flockscreen

An invisible (fake) screen lock for macOS.

> Do not use this app if you want to safely lock your macOS!   
  The locking mechanism of this app can possibly be circumvented!

## Features

* Adds an invisible screen lock
* Takes a picture (and saves it in your "Pictures" folder) if someone triggers the lock

### Lock triggers

* Mouse movements
* Keyboard inputs<sup>[1]</sup>

[1] Only works if you allow the app to control your computer. 
You will be asked about this permission when you first start the app. 
You can manually set it in "System preferences > Security > Privacy > Accessiblity".

## Download

There is currently no official download.

You have to build this app on your own with Xcode. You can download a development build from the [release page](https://github.com/jaylinski/flockscreen/releases).

## How to use

* Start the app (allow the app to control your computer, this is required to capture keyboard inputs)
* Click on the lock icon 🔓 in the status bar
* Click on "Activate lock", the invisible lock will be active after one second
* Get away from your computer and wait for mischievous colleagues trying to tamper with your system
* You will get a notification if some triggered the lock as soon as you unlock macOS again
* You can deactivate the lock by pressing `j` (making this configurable is on the roadmap)

## Requirements

* macOS 10.15 Catalina or greater
* Camera (AVCaptureDevice)

## Roadmap

* Implement preferences with [sindresorhus/Preferences](https://github.com/sindresorhus/Preferences) and SPM
  * Make activation shortcut configurable
  * Make picutres folder configurable
  * Make deactivation (defuse) option configurable
* Try to build app with sandbox enabled, so it can be published in app store
* Add application to [serhii-londar/open-source-mac-os-apps](https://github.com/serhii-londar/open-source-mac-os-apps)


## License

This software is licensed under the MIT License - see the [LICENSE](https://github.com/jaylinski/flockscreen/blob/master/LICENSE) file for details.
