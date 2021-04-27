# Copyright (C) 2018 GeedgeNetworks.
# Geedge/TSG-9140-NPC-v1

ONIE_ARCH ?= x86_64
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

# Vendor ID -- IANA Private Enterprise Number:
# http://www.iana.org/assignments/enterprise-numbers
# Lenovo 
# VENDOR_ID = 19046

# Enable the i2ctools and the onie-syseeprom command for this platform
# I2CTOOLS_ENABLE = yes

# Console parameters
CONSOLE_DEV = 0
CONSOLE_SPEED = 115200
# SERIAL_CONSOLE_ENABLE="no"

#Enable UEFI support
UEFI_ENABLE = yes

# Set Linux kernel version
# LINUX_VERSION		= 5.4
# LINUX_MINOR_VERSION	= 114

# Specify uClibc version
# UCLIBC_VERSION = 0.9.32.1
# GCC_VERSION = 9.3.1

#Extra kernel command line
EXTRA_CMDLINE_LINUX ?= nomodeset debug

#-------------------------------------------------------------------------------
#
# Local Variables:
# mode: makefile-gmake
# End:

