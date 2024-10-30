# Copyright (C) 2018 GeedgeNetworks.
# Geedge/TSG-X_NXR620G40_R01

ONIE_ARCH ?= armv8a
SWITCH_ASIC_VENDOR = none

VENDOR_REV ?= 0

# Translate hardware revision to ONIE hardware revision
ifeq ($(VENDOR_REV),0)
  MACHINE_REV = 0
else
  $(warning Unknown VENDOR_REV '$(VENDOR_REV)' for MACHINE '$(MACHINE)')
  $(error Unknown VENDOR_REV)
endif

# The VENDOR_VERSION string is appended to the overal ONIE version
# string.  HW vendors can use this to appended their own versioning
# information to the base ONIE version string.
# VENDOR_VERSION = .0.3

# Enable the i2ctools and the onie-syseeprom command for this platform
# I2CTOOLS_ENABLE = yes

# Enable UEFI support
UEFI_ENABLE = yes
GRUB_ENABLE ?= yes
UBOOT_ENABLE ?= no
SKIP_ETHMGMT_MACS = yes

# dtb
KERNEL_DTB = hisilicon/hi3660-hikey960.dtb
KERNEL_DTB_PATH = dts/$(KERNEL_DTB)
# FDT_LOAD_ADDRESS = 0x10000000

# Linux kernel
LINUX_VERSION = 5.15
LINUX_MINOR_VERSION = 169
# ONIE_MIRROR	= https://cdn.kernel.org/pub/linux/kernel/v5.x
EXTRA_CMDLINE_LINUX ?= console=tty0

# Specify uClibc version
# UCLIBC_VERSION = 0.9.32.1
# GCC_VERSION = 9.3.1

# IPMITOOL_ENABLE ?= yes

SERIAL_CONSOLE_ENABLE = no

#-------------------------------------------------------------------------------
#
# Local Variables:
# mode: makefile-gmake
# End:

