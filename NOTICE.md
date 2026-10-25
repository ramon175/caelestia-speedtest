# Third-party notices

## Omarchy

`src/assets/speedtest.sh` and the dial scale steps in `src/services/SpeedTest.qml` are adapted from
[Omarchy](https://github.com/basecamp/omarchy) (`bin/omarchy-network-speedtest` and
`shell/Ui/SpeedTestOverlay.qml` on the `quattro` branch), under this license:

```
MIT License

Copyright (c) David Heinemeier Hansson

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

## Caelestia shell

`patches/dashboard-content.patch` modifies `modules/dashboard/Content.qml` from
[caelestia-dots/shell](https://github.com/caelestia-dots/shell), which is licensed under GPL-3.0.
The QML files in `src/` use Caelestia's components and services, so this project is distributed
under GPL-3.0 as well.

## Fast.com

The speed test talks to Netflix's Fast.com service using the public web client token, the same way
Omarchy does. This project has no connection to Netflix.
