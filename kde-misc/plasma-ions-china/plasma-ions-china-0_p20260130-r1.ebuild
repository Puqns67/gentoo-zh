# Copyright 2025-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="A collection of plasma weather ions for Chinese users"
HOMEPAGE="https://github.com/arenekosreal/plasma-ions-china"

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/arenekosreal/plasma-ions-china.git"
else
	SRC_HASH="84eedb4bb3a9addc21b7288aa22b84ef211e3603"
	SRC_URI="https://github.com/arenekosreal/plasma-ions-china/archive/${SRC_HASH}.tar.gz -> ${P}.tar.gz"
	S="${WORKDIR}/${PN}-${SRC_HASH}"
	KEYWORDS="~amd64"
fi

LICENSE="GPL-3+"
SLOT="0"

RDEPEND="
	dev-qt/qtbase:6
	>=kde-plasma/kdeplasma-addons-6.7:=
"
DEPEND="${RDEPEND}"
BDEPEND="kde-frameworks/extra-cmake-modules"

src_configure() {
	local mycmakeargs=( -DPLASMA_IONS_CHINA_USE_SYSTEM_HEADERS=ON )
	cmake_src_configure
}
