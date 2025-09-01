#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#


# 发布固件名称添加日期
# sed -i 's/^IMG_PREFIX\:\=.*/IMG_PREFIX:=IM-$(shell TZ=UTC-8 date +"%Y.%m.%d-%H%M")-$(IMG_PREFIX_VERNUM)$(IMG_PREFIX_VERCODE)$(IMG_PREFIX_EXTRA)$(BOARD)$(if $(SUBTARGET),-$(SUBTARGET))/g' include/image.mk

# 修改默认IP地址
sed -i 's/192.168.1.1/192.168.3.2/g' package/base-files/files/bin/config_generate

# 修改默认主题
# sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 修改主机名
sed -i 's/ImmortalWrt/R7000/g' package/base-files/files/bin/config_generate


# 下载默认设置文件（已注释，如需启用请移除#）
# wget -N https://raw.githubusercontent.com/leesuncom/NetGearR7000/refs/heads/main/default-settings/files/99-default-settings-chinese \
#     -P feeds/package/emortal/default-settings/files/
