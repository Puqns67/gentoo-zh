# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

LLVM_COMPAT=( 22 )
RUST_MIN_VER="1.88.0"

declare -A GIT_CRATES=(
	[mlua-extra]="https://github.com/hypengw/mlua-extra;df1d282170dd1718b8aeff405638c18cedd435ca"
)

inherit llvm-r2 cargo xdg

DESCRIPTION="A dynamic wallpaper solution for Linux desktops"
HOMEPAGE="https://github.com/waywallen/waywallen"

LUA_TAG="5.5.1"
VMA_TAG="3.4.0"
RSTD_COMMIT="fdb99aaa894d76b04032cd301ac82b5ee6e3ec6d"
LUATO_COMMIT="61dd40dca1e9aeda69eed208ddf0d10b34f59db7"
VVK_COMMIT="f53d60cc70938d0485802750deeb15d18ba033ea"
WAVSEN_COMMIT="c7cb2b2304b0b0e309c19373ac0722d904ddebc0"
NCREQUEST_COMMIT="fbf353f079ea7bc5bcf967c3cb04cbf3f6835139"
QEXTRA_COMMIT="98cec17a8576c27fbc39e6d2788926cf676cf1b7"

SRC_URI="
	https://github.com/waywallen/waywallen/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/gentoo-zh-drafts/waywallen/releases/download/v${PV}/waywallen-${PV}-crates.tar.xz
	${CARGO_CRATE_URIS}
	https://lua.org/ftp/lua-${LUA_TAG}.tar.gz
	https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator/archive/refs/tags/v${VMA_TAG}.tar.gz
		-> VulkanMemoryAllocator-${VMA_TAG}.tar.gz
	https://github.com/litocpp/rstd/archive/${RSTD_COMMIT}.tar.gz -> rstd-${RSTD_COMMIT}.tar.gz
	https://github.com/litocpp/luato/archive/${LUATO_COMMIT}.tar.gz -> luato-${LUATO_COMMIT}.tar.gz
	https://github.com/litocpp/vvk/archive/${VVK_COMMIT}.tar.gz -> vvk-${VVK_COMMIT}.tar.gz
	https://github.com/hypengw/wavsen/archive/${WAVSEN_COMMIT}.tar.gz -> wavsen-${WAVSEN_COMMIT}.tar.gz
	ui? (
		https://github.com/hypengw/ncrequest/archive/${NCREQUEST_COMMIT}.tar.gz -> ncrequest-${NCREQUEST_COMMIT}.tar.gz
		https://github.com/hypengw/QExtra/archive/${QEXTRA_COMMIT}.tar.gz -> QExtra-${QEXTRA_COMMIT}.tar.gz
	)
"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

IUSE="+ui pipewire vaapi +wallhaven"

RDEPEND="
	media-plugins/waywallen-display
	app-arch/zstd
	dev-db/sqlite
	dev-libs/glib
	dev-libs/icu
	dev-util/glslang
	media-libs/mesa
	media-libs/vulkan-loader
	media-video/ffmpeg
	net-misc/curl
	virtual/zlib
	ui? (
		dev-libs/qml-material
		dev-qt/qtbase:6[dbus]
		dev-qt/qtdeclarative:6
		dev-qt/qtgrpc:6
		dev-qt/qtwebsockets:6
	)
	pipewire? ( media-video/pipewire )
	!pipewire? ( media-libs/libpulse )
	vaapi? ( media-libs/libva )
"
DEPEND="
	${RDEPEND}
	dev-util/vulkan-headers
"
BDEPEND="
	$(llvm_gen_dep '
		llvm-core/clang:${LLVM_SLOT}=
		llvm-core/lld:${LLVM_SLOT}=
	')
	dev-build/lito
"

PATCHES=(
	"${FILESDIR}/${PN}-0.3.7-build-rust-binary-by-self.patch"
	"${FILESDIR}/${PN}-0.3.7-fix-so-install-path.patch"
	"${FILESDIR}/${PN}-0.3.7-use-system-qml-material.patch"
)

export LIBSQLITE3_SYS_USE_PKG_CONFIG=1
export ZSTD_SYS_USE_PKG_CONFIG=1

src_configure() {
	mkdir .lito
	cat > .lito/config.toml << EOF
[toolchain]
cc = "clang-${LLVM_SLOT}"
cxx = "clang++-${LLVM_SLOT}"
[build]
options = ["-D_FORTIFY_SOURCE=0"]
linker-options = ["-fuse-ld=lld"]
[patch."https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator.git"]
path = "${WORKDIR}/VulkanMemoryAllocator-${VMA_TAG}"
[patch."https://github.com/litocpp/rstd.git"]
path = "${WORKDIR}/rstd-${RSTD_COMMIT}"
[patch."https://github.com/litocpp/luato.git"]
path = "${WORKDIR}/luato-${LUATO_COMMIT}"
[patch."https://github.com/litocpp/vvk.git"]
path = "${WORKDIR}/vvk-${VVK_COMMIT}"
[patch."https://github.com/hypengw/wavsen.git"]
path = "${WORKDIR}/wavsen-${WAVSEN_COMMIT}"
EOF

	if use ui; then
		cat >> .lito/config.toml << EOF
[patch."https://github.com/hypengw/ncrequest.git"]
path = "${WORKDIR}/ncrequest-${NCREQUEST_COMMIT}"
[patch."https://github.com/hypengw/QExtra.git"]
path = "${WORKDIR}/QExtra-${QEXTRA_COMMIT}"
EOF
	else
		eapply "${FILESDIR}/${PN}-0.3.7-no-ui.patch"
	fi

	pushd "${WORKDIR}/luato-${LUATO_COMMIT}" || die
	eapply "${FILESDIR}/${PN}-0.3.7-luato-use-downloaded-lua.patch"
	sed -i "s:LUA_PATH:../../../lua-${LUA_TAG}:" src/lua/lito.toml
	popd || die

	if ! use vaapi; then
		pushd "${WORKDIR}/wavsen-${WAVSEN_COMMIT}" || die
		eapply "${FILESDIR}/${PN}-0.3.7-wavsen-no-vaapi.patch"
		popd || die
	fi

	export mylitopackages=(
		--package waywallen-image-plugin
		--package waywallen-video-plugin
	)

	use ui && mylitopackages+=( --package waywallen-ui )
}

src_compile() {
	cargo_src_compile --bin waywallen

	local mylitoargs=(
		--profile plain
		--offline
		--use-env-flags
		"${mylitopackages[@]}"
	)

	lito build "${mylitoargs[@]}" || die
}

src_install() {
	cargo_src_install --bin waywallen

	local mylitoargs=(
		--profile plain
		--no-build
		--prefix "${ED}/usr"
		"${mylitopackages[@]}"
	)

	use wallhaven && mylitoargs+=( --package waywallen-wallhaven-plugin )

	lito install "${mylitoargs[@]}" || die
}
