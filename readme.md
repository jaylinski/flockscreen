#  flockscreen

A fake screen lock for macOS.

> Do not use this app if you want to safely lock your macOS!   
  The locking mechanism of this app can possibly be circumvented!

## Features

* Takes a picture (and saves it in your "Pictures" folder) if someone triggers the lock

### Lock triggers

* Mouse movements
* Keyboard inputs<sup>[1]</sup>

[1] Only works if you allow the app to control your computer. 
You will be asked about this permission when you first start the app. 
You can manually set it in "System preferences > Security > Privacy > Accessiblity".

## Download

There is currently no download.

You have to build this app on your own with Xcode.

## How to use

* Start the App (you have to build it on your own, allow the app to control your computer)
* Click on "flockscreen" in the status bar
* Click on "Activate", the fake lock will be active after one second
* Get away from your computer and wait for mischievous colleagues trying to tamper with your system

## Roadmap

* Add fancy icon (that reflects if flockscreen is active, if someone activated the lock, if process is trusted)
* Add notfication to notification center if a picture was taken
* Implement preferences with [sindresorhus/Preferences](https://github.com/sindresorhus/Preferences) and SPM
  * Make activation shortcut configurable
  * Make picutres folder configurable
  * Make deactivation (defuse) option configurable
* Add "About" page
* Try to build app with sandbox enabled, so it can be published in app store

## License

This software is licensed under the MIT License - see the [LICENSE](https://github.com/jaylinski/flockscreen/blob/master/LICENSE) file for details.
