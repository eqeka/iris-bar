# Maintainer: eqeka <dmitriukaleksandr@gmail.com>
pkgname=iris-bar-git
pkgver=r1.0000000
pkgrel=1
pkgdesc="Minimal rainbow-gradient status bar for niri, built on Quickshell"
arch=('any')
url="https://github.com/eqeka/iris-bar"
license=('MIT')
depends=('quickshell' 'lm_sensors' 'brightnessctl' 'wireplumber')
optdepends=('niri: keyboard layout indicator'
            'nvidia-utils: GPU usage reporting via nvidia-smi')
makedepends=('git')
provides=('iris-bar')
conflicts=('iris-bar')
source=("$pkgname::git+https://github.com/eqeka/iris-bar.git")
sha256sums=('SKIP')

pkgver() {
  cd "$pkgname"
  printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

package() {
  install -dm755 "$pkgdir/etc/xdg/quickshell/iris-bar"
  install -m755 "$srcdir/$pkgname/collector.sh" "$pkgdir/etc/xdg/quickshell/iris-bar/"
  install -m644 "$srcdir/$pkgname/config.sh" "$pkgdir/etc/xdg/quickshell/iris-bar/"
  install -m644 "$srcdir/$pkgname/shell.qml" "$pkgdir/etc/xdg/quickshell/iris-bar/"
  install -Dm644 "$srcdir/$pkgname/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
