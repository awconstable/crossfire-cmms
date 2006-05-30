/* config.h.  Generated automatically by configure.  */
/* config.h.in.  Generated automatically from configure.in by autoheader 2.13.  */

/* Define to empty if the keyword does not work.  */
/* #undef const */

/* Define to `int' if <sys/types.h> doesn't define.  */
/* #undef gid_t */

/* Define as __inline if that's what the C compiler calls it.  */
/* #undef inline */

/* Define as the return type of signal handlers (int or void).  */
#define RETSIGTYPE void

/* Define to `unsigned' if <sys/types.h> doesn't define.  */
/* #undef size_t */

/* Define if you have the ANSI C header files.  */
#define STDC_HEADERS 1

/* Define if you can safely include both <sys/time.h> and <time.h>.  */
#define TIME_WITH_SYS_TIME 1

/* Define if your <sys/time.h> declares struct tm.  */
/* #undef TM_IN_SYS_TIME */

/* Define to `int' if <sys/types.h> doesn't define.  */
/* #undef uid_t */

#define BAYRAD_DRV 1

#define CFONTZ_DRV 1

#define CWLNX_DRV 1

#define CURSES_DRV 1

/* #undef CURSES_HAS__ACS_CHAR */

#define CURSES_HAS_ACS_MAP 1

#define CURSES_HAS_REDRAWWIN 1

#define CURSES_HAS_WCOLOR_SET 1

/* #undef DEBUG */

#define GLK_DRV 1

/* #undef HD44780_DRV */

/* #undef IRMANIN_DRV */

/* #undef JOY_DRV */

#define LB216_DRV 1

#define LCDM001_DRV 1

#define LCDPORT 13666

/* #undef LIRCIN_DRV */

#define LOAD_MAX 1.3

#define LOAD_MIN 0.05

#define MTXORB_DRV 1

/* #undef SED1330_DRV */

/* #undef SED1520_DRV */

#define SGX120_DRV 1

/* #undef STV5730_DRV */

/* #undef SVGALIB_DRV */

/* #undef T6963_DRV */

/* Define the protocol version */
#define PROTOCOL_VERSION "0.3"

#define API_VERSION "0.4"

/* #undef WIRZSLI_DRV */

/* #undef STAT_NFS */

/* #undef STAT_SMBFS */

/* two-argument statfs with statfs.bsize member (AIX, 4.3BSD) */
/* #undef STAT_STATFS2_BSIZE */

/* two-argument statfs with statfs.fsize member (4.4BSD and NetBSD) */
/* #undef STAT_STATFS2_FSIZE */

/* two-argument statfs with struct fs_data (Ultrix) */
/* #undef STAT_STATFS2_FS_DATA */

/* 3-argument statfs function (DEC OSF/1) */
/* #undef STAT_STATFS3_OSF1 */

/* four-argument statfs (AIX-3.2.5, SVR3) */
/* #undef STAT_STATFS4 */

/* Define if you have the statvfs function */
#define STAT_STATVFS 1

/* #undef SVGALIB_DRV */

#define TEXT_DRV 1

/* #undef T6963_DRV */

/* Define if you have the cfmakeraw function.  */
#define HAVE_CFMAKERAW 1

/* Define if you have the getloadavg function.  */
#define HAVE_GETLOADAVG 1

/* Define if you have the getmntinfo function.  */
/* #undef HAVE_GETMNTINFO */

/* Define if you have the ioperm function.  */
#define HAVE_IOPERM 1

/* Define if you have the sched_setscheduler function.  */
#define HAVE_SCHED_SETSCHEDULER 1

/* Define if you have the select function.  */
#define HAVE_SELECT 1

/* Define if you have the socket function.  */
#define HAVE_SOCKET 1

/* Define if you have the statvfs function.  */
#define HAVE_STATVFS 1

/* Define if you have the strdup function.  */
#define HAVE_STRDUP 1

/* Define if you have the strerror function.  */
#define HAVE_STRERROR 1

/* Define if you have the strtol function.  */
#define HAVE_STRTOL 1

/* Define if you have the swapctl function.  */
/* #undef HAVE_SWAPCTL */

/* Define if you have the uname function.  */
#define HAVE_UNAME 1

/* Define if you have the <curses.h> header file.  */
#define HAVE_CURSES_H 1

/* Define if you have the <dirent.h> header file.  */
#define HAVE_DIRENT_H 1

/* Define if you have the <errno.h> header file.  */
#define HAVE_ERRNO_H 1

/* Define if you have the <fcntl.h> header file.  */
#define HAVE_FCNTL_H 1

/* Define if you have the <kvm.h> header file.  */
/* #undef HAVE_KVM_H */

/* Define if you have the <limits.h> header file.  */
#define HAVE_LIMITS_H 1

/* Define if you have the <machine/cpufunc.h> header file.  */
/* #undef HAVE_MACHINE_CPUFUNC_H */

/* Define if you have the <machine/pio.h> header file.  */
/* #undef HAVE_MACHINE_PIO_H */

/* Define if you have the <machine/sysarch.h> header file.  */
/* #undef HAVE_MACHINE_SYSARCH_H */

/* Define if you have the <mntent.h> header file.  */
#define HAVE_MNTENT_H 1

/* Define if you have the <mnttab.h> header file.  */
/* #undef HAVE_MNTTAB_H */

/* Define if you have the <ncurses.h> header file.  */
#define HAVE_NCURSES_H 1

/* Define if you have the <ndir.h> header file.  */
/* #undef HAVE_NDIR_H */

/* Define if you have the <procfs.h> header file.  */
/* #undef HAVE_PROCFS_H */

/* Define if you have the <sched.h> header file.  */
#define HAVE_SCHED_H 1

/* Define if you have the <sys/cpuvar.h> header file.  */
/* #undef HAVE_SYS_CPUVAR_H */

/* Define if you have the <sys/dir.h> header file.  */
/* #undef HAVE_SYS_DIR_H */

/* Define if you have the <sys/dkstat.h> header file.  */
/* #undef HAVE_SYS_DKSTAT_H */

/* Define if you have the <sys/dustat.h> header file.  */
/* #undef HAVE_SYS_DUSTAT_H */

/* Define if you have the <sys/filsys.h> header file.  */
/* #undef HAVE_SYS_FILSYS_H */

/* Define if you have the <sys/fs_types.h> header file.  */
/* #undef HAVE_SYS_FS_TYPES_H */

/* Define if you have the <sys/fstyp.h> header file.  */
/* #undef HAVE_SYS_FSTYP_H */

/* Define if you have the <sys/io.h> header file.  */
#define HAVE_SYS_IO_H 1

/* Define if you have the <sys/ioctl.h> header file.  */
#define HAVE_SYS_IOCTL_H 1

/* Define if you have the <sys/loadavg.h> header file.  */
/* #undef HAVE_SYS_LOADAVG_H */

/* Define if you have the <sys/mount.h> header file.  */
#define HAVE_SYS_MOUNT_H 1

/* Define if you have the <sys/ndir.h> header file.  */
/* #undef HAVE_SYS_NDIR_H */

/* Define if you have the <sys/param.h> header file.  */
#define HAVE_SYS_PARAM_H 1

/* Define if you have the <sys/perm.h> header file.  */
#define HAVE_SYS_PERM_H 1

/* Define if you have the <sys/procfs.h> header file.  */
#define HAVE_SYS_PROCFS_H 1

/* Define if you have the <sys/sched.h> header file.  */
/* #undef HAVE_SYS_SCHED_H */

/* Define if you have the <sys/statfs.h> header file.  */
#define HAVE_SYS_STATFS_H 1

/* Define if you have the <sys/statvfs.h> header file.  */
#define HAVE_SYS_STATVFS_H 1

/* Define if you have the <sys/sysctl.h> header file.  */
#define HAVE_SYS_SYSCTL_H 1

/* Define if you have the <sys/time.h> header file.  */
#define HAVE_SYS_TIME_H 1

/* Define if you have the <sys/types.h> header file.  */
#define HAVE_SYS_TYPES_H 1

/* Define if you have the <sys/vfs.h> header file.  */
#define HAVE_SYS_VFS_H 1

/* Define if you have the <unistd.h> header file.  */
#define HAVE_UNISTD_H 1

/* Define if you have the <utime.h> header file.  */
#define HAVE_UTIME_H 1

/* Define if you have the <utmpx.h> header file.  */
#define HAVE_UTMPX_H 1

/* Define if you have the c library (-lc).  */
/* #undef HAVE_LIBC */

/* Define if you have the i386 library (-li386).  */
/* #undef HAVE_LIBI386 */

/* Define if you have the kstat library (-lkstat).  */
/* #undef HAVE_LIBKSTAT */

/* Define if you have the nsl library (-lnsl).  */
/* #undef HAVE_LIBNSL */

/* Define if you have the posix4 library (-lposix4).  */
/* #undef HAVE_LIBPOSIX4 */

/* Define if you have the resolv library (-lresolv).  */
/* #undef HAVE_LIBRESOLV */

/* Define if you have the rt library (-lrt).  */
#define HAVE_LIBRT 1

/* Define if you have the socket library (-lsocket).  */
/* #undef HAVE_LIBSOCKET */

/* Name of package */
#define PACKAGE "lcdproc"

/* Version number of package */
#define VERSION "0.4.5"

/* Define if you're using Linux. */
#define LINUX 1

/* Define if you're using Solaris. */
/* #undef SOLARIS */

/* Define if you're using OpenBSD. */
/* #undef OPENBSD */

/* Define if you're using NetBSD. */
/* #undef NETBSD */

/* Define if you're using FreeBSD. */
/* #undef FREEBSD */

/* Set this to your system host (Linux, Solaris, OpenBSD, NetBSD or FreeBSD) */
#define SYSTEM_HOST Linux

/*  Define if you have System V IPC  */
#define HAVE_SYSV_IPC 1

/*  Define if your system's sys/sem.h file defines union semun  */
/* #undef HAVE_UNION_SEMUN */

/* Define if you have the sched_setscheduler function. */
#define HAVE_SCHED_SETSCHEDULER 1

/* Define if you have the sched_setscheduler function. */
#define HAVE_SCHED_SETSCHEDULER 1

/* Define if you have the NetBSD&OpenBSD version of i386_ioperm functions. */
/* #undef HAVE_I386_IOPERM_NETBSD */

/* Define if you have the FreeBSD version of the i386_ioperm functions. */
/* #undef HAVE_I386_IOPERM_FREEBSD */

/* Define if you have a parallel port and LCDproc knows how to talk to it. */
#define HAVE_PCSTYLE_LPT_CONTROL 1

/* Location of your mounted filesystem table file */
#define MTAB_FILE "/etc/mtab"

