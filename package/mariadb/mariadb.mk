################################################################################
#
# mariadb
#
################################################################################

MARIADB_VERSION = 10.11.11
MARIADB_SITE = https://downloads.mariadb.org/interstitial/mariadb-$(MARIADB_VERSION)/source
MARIADB_LICENSE = GPL-2.0 (server), GPL-2.0 with FLOSS exception (GPL client library), LGPL-2.0 (LGPL client library)
# Tarball no longer contains LGPL license text
# https://jira.mariadb.org/browse/MDEV-12297
MARIADB_LICENSE_FILES = README.md COPYING
MARIADB_CPE_ID_VENDOR = mariadb
MARIADB_SELINUX_MODULES = mysql
MARIADB_INSTALL_STAGING = YES
MARIADB_CONFIG_SCRIPTS = mysql_config

MARIADB_DEPENDENCIES = \
	host-mariadb \
	fmt \
	ncurses \
	openssl \
	pcre2 \
	zlib \
	libaio \
	libxml2

MARIADB_CONF_OPTS += \
	-DWITH_LIBFMT=system \
	-DWITH_PCRE=system \
	-DHAVE_SYSTEM_LIBFMT_EXITCODE=0

# use bundled GPL-2.0+ licensed readline as package/readline is GPL-3.0+
MARIADB_CONF_OPTS += -DWITH_READLINE=ON

# We won't need unit tests
MARIADB_CONF_OPTS += -DWITH_UNIT_TESTS=0

# Mroonga needs libstemmer. Some work still needs to be done before it can be
# included in buildroot. Disable it for now.
MARIADB_CONF_OPTS += -DWITHOUT_MROONGA=1

# This value is determined automatically during straight compile by compiling
# and running a test code. You cannot do that during cross-compile. However the
# stack grows downward in most if not all modern systems. The only exception I
# am aware of is PA-RISC which is not supported by buildroot. Therefore it makes
# sense to hardcode the value. If an arch is added the stack of which grows up
# one should expect unpredictable behavior at run time.
MARIADB_CONF_OPTS += -DSTACK_DIRECTION=-1

# Jemalloc was added for TokuDB. Since its configure script seems somewhat broken
# when it comes to cross-compilation we shall disable it and also disable TokuDB.
MARIADB_CONF_OPTS += -DWITH_JEMALLOC=no -DWITHOUT_TOKUDB=1

# RocksDB fails to build in some configurations with the following build error:
# ./output/build/mariadb-10.2.17/storage/rocksdb/rocksdb/utilities/backupable/backupable_db.cc:327:38:
# error: field 'result' has incomplete type 'std::promise<rocksdb::BackupEngineImpl::CopyOrCreateResult>'
#     std::promise<CopyOrCreateResult> result;
#
# To work around the issue, we disable RocksDB
MARIADB_CONF_OPTS += -DWITHOUT_ROCKSDB=1

# Make it explicit that we are cross-compiling
MARIADB_CONF_OPTS += -DCMAKE_CROSSCOMPILING=1

# Explicitly disable dtrace to avoid detection of a host version
MARIADB_CONF_OPTS += -DENABLE_DTRACE=0

ifeq ($(BR2_PACKAGE_LIBRESSL),y)
MARIADB_CONF_OPTS += \
	-DLIBRESSL_RESULT=ON \
	-DLIBRESSL_RESULT__TRYRUN_OUTPUT="LibreSSL $(LIBRESSL_VERSION)"
endif

ifeq ($(BR2_PACKAGE_SYSTEMD),y)
MARIADB_DEPENDENCIES += systemd
MARIADB_CONF_OPTS += -DWITH_SYSTEMD=yes
else
MARIADB_CONF_OPTS += -DWITH_SYSTEMD=no
endif

ifeq ($(BR2_PACKAGE_MARIADB_SERVER),y)
ifeq ($(BR2_PACKAGE_MARIADB_SERVER_EMBEDDED),y)
MARIADB_CONF_OPTS += -DWITH_EMBEDDED_SERVER=ON
else
MARIADB_CONF_OPTS += -DWITH_EMBEDDED_SERVER=OFF
endif
else
MARIADB_CONF_OPTS += -DWITHOUT_SERVER=ON
endif

MARIADB_CXXFLAGS = $(TARGET_CXXFLAGS)

ifeq ($(BR2_TOOLCHAIN_HAS_LIBATOMIC),y)
MARIADB_CXXFLAGS += -latomic
endif

ifeq ($(BR2_TOOLCHAIN_HAS_GCC_BUG_68485),y)
MARIADB_CXXFLAGS += -O0
endif

MARIADB_CONF_OPTS += \
	-DCMAKE_CXX_FLAGS="$(MARIADB_CXXFLAGS)" \
	-DINSTALL_DOCDIR=share/doc/mariadb-$(MARIADB_VERSION) \
	-DINSTALL_DOCREADMEDIR=share/doc/mariadb-$(MARIADB_VERSION) \
	-DINSTALL_MANDIR=share/man \
	-DINSTALL_MYSQLSHAREDIR=share/mysql \
	-DINSTALL_MYSQLTESTDIR=share/mysql/test \
	-DINSTALL_PLUGINDIR=lib/mysql/plugin \
	-DINSTALL_SBINDIR=sbin \
	-DINSTALL_SCRIPTDIR=bin \
	-DINSTALL_SQLBENCHDIR=share/mysql/bench \
	-DINSTALL_SUPPORTFILESDIR=share/mysql \
	-DMYSQL_DATADIR=/var/lib/mysql \
	-DMYSQL_UNIX_ADDR=$(MYSQL_SOCKET)

HOST_MARIADB_DEPENDENCIES = host-openssl
HOST_MARIADB_CONF_OPTS += -DWITH_SSL=system

# Some helpers must be compiled for host in order to crosscompile mariadb for
# the target. They are then included by import_executables.cmake which is
# generated during the build of the host helpers. It is not necessary to build
# the whole host package, only the "import_executables" target.
# -DIMPORT_EXECUTABLES=$(HOST_MARIADB_BUILDDIR)/import_executables.cmake
# must then be passed to cmake during target build.
# see also https://mariadb.com/kb/en/mariadb/cross-compiling-mariadb/
HOST_MARIADB_MAKE_OPTS = import_executables

MARIADB_CONF_OPTS += \
	-DIMPORT_EXECUTABLES=$(HOST_MARIADB_BUILDDIR)/import_executables.cmake

# Don't install host-mariadb. We just need to build import_executable
# Therefore only run 'true' and do nothing, not even the default action.
HOST_MARIADB_INSTALL_CMDS = true

ifeq ($(BR2_PACKAGE_MARIADB_SERVER),y)
define MARIADB_USERS
	mysql -1 mysql -1 * /var/lib/mysql - - MySQL Server
endef

define MARIADB_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 package/mariadb/S97mysqld \
		$(TARGET_DIR)/etc/init.d/S97mysqld
endef

define MARIADB_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 644 package/mariadb/mysqld.service \
		$(TARGET_DIR)/usr/lib/systemd/system/mysqld.service
endef
endif

# We don't need mysql_config or mariadb_config on the target as it's
# only useful in staging. We also don't need the test suite on the target.
define MARIADB_POST_INSTALL
	mkdir -p $(TARGET_DIR)/var/lib/mysql
	$(RM) $(TARGET_DIR)/usr/bin/mysql_config
	$(RM) $(TARGET_DIR)/usr/bin/mariadb_config
	$(RM) -r $(TARGET_DIR)/usr/share/mysql/test
endef

MARIADB_POST_INSTALL_TARGET_HOOKS += MARIADB_POST_INSTALL

# overwrite cross-compiled mariadb_config executable by an native one
define MARIADB_POST_STAGING_INSTALL
	$(HOSTCC) -I$(@D)/libmariadb/include \
		-o $(STAGING_DIR)/usr/bin/mariadb_config \
		$(@D)/libmariadb/mariadb_config/mariadb_config.c
endef
MARIADB_POST_INSTALL_STAGING_HOOKS += MARIADB_POST_STAGING_INSTALL

$(eval $(cmake-package))
$(eval $(host-cmake-package))
