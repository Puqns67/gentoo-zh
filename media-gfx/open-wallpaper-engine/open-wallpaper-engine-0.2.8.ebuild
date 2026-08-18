# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

LLVM_COMPAT=( 22 )

inherit llvm-r2

DESCRIPTION="A dynamic wallpaper solution for Linux desktops"
HOMEPAGE="https://github.com/waywallen/open-wallpaper-engine"

EIGEN_TAG="5.0.1"
SPIRV_REFLECT_TAG="1.4.321.0"
VMA_TAG="3.4.0"
RSTD_COMMIT="a852e89dc7b2c7fae6cc4c89d1f76afbac55be82"
VVK_COMMIT="f53d60cc70938d0485802750deeb15d18ba033ea"
WAVSEN_COMMIT="c07711f73253b0e3c53329c9930f2024193f8641"
declare -A CEF_FILENAMES=(
	[amd64]="cef_binary_149.0.4+g2f1bfd8+chromium-149.0.7827.156_linux64_minimal"
	[arm64]="cef_binary_149.0.4+g2f1bfd8+chromium-149.0.7827.156_linuxarm64_minimal"
)

SRC_URI="
	https://github.com/waywallen/open-wallpaper-engine/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	https://gitlab.com/libeigen/eigen/-/archive/${EIGEN_TAG}/eigen-${EIGEN_TAG}.tar.bz2
	https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator/archive/refs/tags/v${VMA_TAG}.tar.gz
		-> VulkanMemoryAllocator-${VMA_TAG}.tar.gz
	https://github.com/litocpp/rstd/archive/${RSTD_COMMIT}.tar.gz -> rstd-${RSTD_COMMIT}.tar.gz
	https://github.com/litocpp/vvk/archive/${VVK_COMMIT}.tar.gz -> vvk-${VVK_COMMIT}.tar.gz
	https://github.com/hypengw/wavsen/archive/${WAVSEN_COMMIT}.tar.gz -> wavsen-${WAVSEN_COMMIT}.tar.gz
	scene? (
		https://github.com/KhronosGroup/SPIRV-Reflect/archive/refs/tags/vulkan-sdk-${SPIRV_REFLECT_TAG}.tar.gz
			-> SPIRV-Reflect-${SPIRV_REFLECT_TAG}.tar.gz
	)
	web? (
		amd64? ( https://cef-builds.spotifycdn.com/${CEF_FILENAMES[amd64]}.tar.bz2 )
		arm64? ( https://cef-builds.spotifycdn.com/${CEF_FILENAMES[arm64]}.tar.bz2 )
	)
"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

IUSE="+scene +web +waywallen +viewer vaapi"
REQUIRED_USE="
	web? ( || ( amd64 arm64 ) )
	waywallen? ( scene web )
	|| ( scene web )
	|| ( waywallen viewer )
"

RDEPEND="
	dev-libs/glib
	dev-libs/icu
	dev-util/glslang
	media-libs/libpulse
	media-libs/mesa
	media-libs/vulkan-loader
	media-video/ffmpeg
	virtual/zlib
	scene? (
		app-arch/lz4
		dev-libs/quickjs-ng
		media-libs/fontconfig
		media-libs/freetype
	)
	web? (
		dev-libs/nspr
		dev-libs/nss
		viewer? ( media-libs/glfw[X] )
	)
	waywallen? ( gui-apps/waywallen )
	viewer? ( media-libs/glfw )
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
	"${FILESDIR}/${PN}-0.2.8-use-system-deps.patch"
)

src_prepare() {
	default_src_prepare

	mkdir .lito
	cat > .lito/config.toml << EOF
[toolchain]
cc="clang-${LLVM_SLOT}"
cxx="clang++-${LLVM_SLOT}"
[build]
options = ["-D_FORTIFY_SOURCE=0"]
linker-options = ["-fuse-ld=lld"]
[patch."https://gitlab.com/libeigen/eigen.git"]
path="${WORKDIR}/eigen-${EIGEN_TAG}"
[patch."https://github.com/hypengw/SPIRV-Reflect.git"]
path="${WORKDIR}/SPIRV-Reflect-vulkan-sdk-${SPIRV_REFLECT_TAG}"
[patch."https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator.git"]
path="${WORKDIR}/VulkanMemoryAllocator-${VMA_TAG}"
[patch."https://github.com/litocpp/rstd.git"]
path="${WORKDIR}/rstd-${RSTD_COMMIT}"
[patch."https://github.com/litocpp/vvk.git"]
path="${WORKDIR}/vvk-${VVK_COMMIT}"
[patch."https://github.com/hypengw/wavsen.git"]
path="${WORKDIR}/wavsen-${WAVSEN_COMMIT}"
EOF

	# Add lito config for SPIRV-Reflect
	cp "${FILESDIR}/SPIRV-Reflect-1.4.321.0.lito.toml" \
		"${WORKDIR}/SPIRV-Reflect-vulkan-sdk-${SPIRV_REFLECT_TAG}/lito.toml"

	if ! use vaapi; then
		pushd "${WORKDIR}/wavsen-${WAVSEN_COMMIT}" || die
		eapply "${FILESDIR}/${PN}-0.2.8-wavsen-no-vaapi.patch"
		popd || die
	fi

	if use web; then
		pushd "${WORKDIR}/${CEF_FILENAMES[${ARCH}]}" || die
		eapply "${FILESDIR}/${PN}-0.1.9-cef-remove-march.patch"
		eapply "${FILESDIR}/${PN}-0.1.9-let-libcef_dll_wrapper-static.patch"
		popd || die
		sed -i "s:CEF_PATH:../${CEF_FILENAMES[$ARCH]}:" lito.toml || die
	else
		eapply "${FILESDIR}/${PN}-0.2.8-no-libcef.patch"
	fi

	export mylitopackages=()

	if use viewer; then
		use scene && mylitopackages+=( --package owe-sceneviewer )
		use web && mylitopackages+=( --package owe-webviewer )
	fi

	if use waywallen; then
		mylitoargs+=(
			--package owe-waywallen-scene-renderer
			--package owe-waywallen-web-renderer
		)
	fi
}

src_compile() {
	local mylitoargs=(
		--profile plain
		--offline
		--use-env-flags
		"${mylitopackages[@]}"
	)


	lito build "${mylitoargs[@]}" || die
}

src_install() {
	local mylitoargs=(
		--profile plain
		--no-build
		--prefix "${ED}/usr"
		"${mylitopackages[@]}"
	)

	if use waywallen; then
		mylitoargs+=(
			--package owe-waywallen-scene-renderer
			--package owe-waywallen-web-renderer
			--package owe-waywallen-plugin
		)
	fi

	lito install "${mylitoargs[@]}" || die
}
