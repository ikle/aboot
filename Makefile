#
# aboot/Makefile
#
# This file is subject to the terms and conditions of the GNU General Public
# License.  See the file "COPYING" in the main directory of this archive
# for more details.
#
# Copyright (c) 1995, 1996 by David Mosberger (davidm@cs.arizona.edu)
#

# location of linux kernel sources (must be absolute path):
KSRC		= /usr/src/linux
VMLINUX		= $(KSRC)/vmlinux
VMLINUXGZ	= $(KSRC)/arch/alpha/boot/vmlinux.gz

# for userspace testing
#TESTING	= yes

# for boot testing
#CFGDEFS       	= -DDEBUG_ISO -DDEBUG_ROCK -DDEBUG_EXT2 -DDEBUG

HOSTCC ?= cc -O2 -Wl,-s
CROSS_COMPILE ?= alpha-linux-gnu-

AS	= $(CROSS_COMPILE)as
CC	= $(CROSS_COMPILE)gcc
LD	= $(CROSS_COMPILE)ld
STRIP	= $(CROSS_COMPILE)strip

# root, aka prefix
root		=
bindir		= $(root)/sbin
bootdir		= $(root)/boot
mandir         = $(root)/usr/share/man

export

#
# There shouldn't be any need to change anything below this line.
#
LOADADDR	= 20000000

ABOOT_LDFLAGS = -static -nostdlib -N -Taboot.lds --relax

ifeq ($(TESTING),)
override CPPFLAGS	+= $(CFGDEFS) -U_FORTIFY_SOURCE -Iinclude
override CFLAGS		+= $(CPPFLAGS) -Os -Wall -ffreestanding -mno-fp-regs -msmall-data -msmall-text
else
override CPPFLAGS	+= -DTESTING $(CFGDEFS) -U_FORTIFY_SOURCE -Iinclude
override CFLAGS		+= $(CPPFLAGS) -O -g3 -Wall
endif

override ASFLAGS	+= $(CPPFLAGS)


.c.s:
	$(CC) $(CFLAGS) -S -o $*.s $<
.s.o:
	$(AS) -o $*.o $<
.c.o:
	$(CC) $(CFLAGS) -c -o $*.o $<
.S.s:
	$(CC) $(ASFLAGS) -D__ASSEMBLY__ -E -o $*.o $<
.S.o:
	$(CC) $(ASFLAGS) -D__ASSEMBLY__ -c -o $*.o $<

NET_OBJS = net.o
DISK_OBJS = disk.o fs/ext2.o fs/ufs.o fs/dummy.o fs/iso.o
ifeq ($(TESTING),)
ABOOT_OBJS = \
	head.o aboot.o cons.o utils.o \
	zip/misc.o zip/unzip.o zip/inflate.o
else
ABOOT_OBJS = aboot.o zip/misc.o zip/unzip.o zip/inflate.o
endif
LIBS	= lib/libaboot.a

ifeq ($(TESTING),)
all:	diskboot
else
all:	aboot
endif

.PHONY: all clean install all-native clean-native install-native distclean

all: diskboot

#
# Native tools for cross build
#

all-native: diskboot-native

clean-native:
	$(RM) *-native tools/*-native tools/*-native.o
	$(RM) sdisklabel/*-native sdisklabel/-native.o

clean: clean-native

%-native.o: %.c
	$(HOSTCC) -c -Iinclude -Itools $< -o $@

%-native: %.c
	$(HOSTCC) -Iinclude -Itools $^ -o $@

tools/e2writeboot-native: tools/bio-native.o tools/e2lib-native.o
tools/isomarkboot-native: tools/isolib-native.o

sdisklabel/sdisklabel-native: sdisklabel/library-native.o
sdisklabel/swriteboot-native: sdisklabel/library-native.o

diskboot-native: bootlx tools/abootconf-native tools/e2writeboot-native
diskboot-native: tools/elfencap-native tools/isomarkboot-native
diskboot-native: sdisklabel/sdisklabel-native sdisklabel/swriteboot-native

#
# Target tools
#
.PHONY: diskboot netboot

diskboot:	bootlx sdisklabel/sdisklabel sdisklabel/swriteboot \
		tools/e2writeboot tools/isomarkboot tools/abootconf \
		tools/elfencap

netboot: vmlinux.bootp

bootloader.h: net-aboot.nh b2c-native
	./b2c-native net-aboot.nh bootloader.h bootloader

netabootwrap: netabootwrap.c bootloader.h
	$(CC) $@.c $(CFLAGS) -o $@

bootlx:	aboot tools/objstrip-native
	tools/objstrip-native -vb aboot bootlx

.PHONY: doc clean-doc install-man install-man-gz installondisk

doc:
	$(MAKE) -C doc/faq
	$(MAKE) -C doc/man

clean-doc:
	$(MAKE) -C doc/faq clean
	$(MAKE) -C doc/man clean

clean: clean-doc

install-man: 
	make -C doc/man install

install-man-gz:
	make -C doc/man install-gz

install: tools/abootconf tools/e2writeboot tools/isomarkboot \
	sdisklabel/swriteboot install-man
	install -d $(bindir) $(bootdir)
	install -c tools/abootconf $(bindir)
	install -c tools/e2writeboot $(bindir)
	install -c tools/isomarkboot $(bindir)
	install -c sdisklabel/swriteboot $(bindir)
	install -c bootlx $(bootdir)

installondisk:	bootlx sdisklabel/swriteboot
	sdisklabel/swriteboot -vf0 /dev/sda bootlx vmlinux.gz

ifeq ($(TESTING),)
aboot:	$(ABOOT_OBJS) $(DISK_OBJS) $(LIBS)
	$(LD) $(ABOOT_LDFLAGS) $(ABOOT_OBJS) $(DISK_OBJS) -o $@ $(LIBS)
else
aboot:	$(ABOOT_OBJS) $(DISK_OBJS) $(LIBS)
	$(CC) $(ABOOT_OBJS) $(DISK_OBJS) -o $@ $(LIBS)
endif

vmlinux.bootp: net-aboot.nh $(VMLINUXGZ) net-pad
	cat net-aboot.nh $(VMLINUXGZ) net-pad > $@

net-aboot.nh: net-aboot tools/objstrip-native
	$(STRIP) net-aboot
	tools/objstrip-native -vb net-aboot $@

net-aboot: $(ABOOT_OBJS) $(ABOOT_OBJS) $(NET_OBJS) $(LIBS)
	$(LD) $(ABOOT_LDFLAGS) $(ABOOT_OBJS) $(NET_OBJS) -o $@ $(LIBS)

net-pad:
	dd if=/dev/zero of=$@ bs=512 count=1

clean:	tools/clean lib/clean
	rm -f aboot abootconf net-aboot net-aboot.nh net-pad vmlinux.bootp \
		$(ABOOT_OBJS) $(DISK_OBJS) $(NET_OBJS) bootlx \
		include/ksize.h vmlinux.nh bootloader.h netabootwrap
	make -C sdisklabel clean

distclean: clean
	find . -name \*~ | xargs rm -f

lib/%:
	make -C lib $* CPPFLAGS="$(CPPFLAGS)" TESTING="$(TESTING)"

tools/%:
	make -C tools $* CPPFLAGS="$(CPPFLAGS)"

sdisklabel/sdisklabel sdisklabel/swriteboot:
	make -C sdisklabel $* CPPFLAGS="$(CPPFLAGS)"

vmlinux.nh: $(VMLINUX) tools/objstrip-native
	tools/objstrip-native -vb $(VMLINUX) vmlinux.nh

include/ksize.h: vmlinux.nh
	echo "#define KERNEL_SIZE `ls -l vmlinux.nh | awk '{print $$5}'` > $@

dep:
