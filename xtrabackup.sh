#!/bin/bash
#用于备份mysql
#使用xtrabackup增量备份
#备份策略：1. 每周日进行一次全备
#          2. 周一至周六每天对前一天的备份文件进行一次增量
#          3. 在每周日进行全备之后，删除前前一次的所有备份
#参数定义：1. 每周的所有备份放在一个目录内，定义名称为year_week
#          2. year_week目录内，每天的备份为一个文件夹，定义名称为0-6，周日为0
#脚本流程：1. 当天的date值，dt=`date +%Y_%U`，判断本周的目录是否存在，如不存在则生成
#          2. 当天的目录值，subdir=`date +%w`，判断是否存在，如不存在则生成，存在则在新目录备份${subdir}_$(date +%H:%M:%S)
#          3. 备份mysql
#          4. 删除以前的备份
 
#init
dt=`date '+%Y%m%d %H:%M:%S'`
year=`date +%Y`
week=`date +%U`
subdir=`date +%w`
basedir=/home/backup
mysql_full_backup ()
{
    xtrabackup --defaults-file=my.cnf --backup --target-dir=$1
}
mysql_incremental_backup ()
{
    xtrabackup --defaults-file=my.cnf --backup --target-dir=$1 --incremental-basedir=$2
}
 
#start
cd $basedir
echo "---mysql backup start---$dt---" >> $basedir/bak.log
#判断文件夹是否存在，不存在则创建
if [ -d ${year}_${week} ];
then
    cd ${year}_${week}
    rootdir=`find . -maxdepth 1 -type f -exec grep -l root {} \;`
    if [ -d $subdir -a -f .${subdir}.lock ];
    then
       mkdir ${subdir}_$(date +%H:%M:%S)
       if [ -n "$rootdir" ];
       then
           point=`echo $rootdir|awk -F'[./_]' '{print $4}'`
           echo "we need a incremental backup! and the root dir is $point" >> $basedir/bak.log
           mysql_incremental_backup ${subdir}_$(date +%H:%M:%S) $point
           [ "$?" -eq 0 ] && touch .${subdir}_$(date +%H:%M:%S).lock
           echo "incremental backup complete!!" >> $basedir/bak.log
       else
           echo "we need a full backup" >> $basedir/bak.log
           mysql_full_backup ${subdir}_$(date +%H:%M:%S)
           [ "$?" -eq 0 ] && echo root > .${subdir}_$(date +%H:%M:%S).lock
           echo "full backup complete!! and the root dir is $subdir_$(date +%H:%M:%S)"  >> $basedir/bak.log
       fi
    else
       rm -rf $subdir .${subdir}.lock ; mkdir $subdir
       if [ -n "$rootdir" ];
       then
           point=`echo $rootdir|awk -F'[./_]' '{print $4}'`
           echo "we need a incremental backup! and the root dir is $point" >> $basedir/bak.log
           mysql_incremental_backup ${subdir} $point
           [ "$?" -eq 0 ] && touch .${subdir}.lock
           echo "incremental backup complete!!" >> $basedir/bak.log
       else
           echo "we need a full backup" >> $basedir/bak.log
           mysql_full_backup ${subdir}
           [ "$?" -eq 0 ] && echo root > .${subdir}.lock
           echo "full backup complete!! and the root dir is $subdir"  >> $basedir/bak.log
       fi
                                                                                                                               fi
else
    mkdir ${year}_${week}
    cd ${year}_${week}
    echo "we need a full backup" >> $basedir/bak.log
    mysql_full_backup ${subdir}
    [ "$?" -eq 0 ] && echo root > .${subdir}.lock
    echo "full backup complete!! and the root dir is $subdir"  >> $basedir/bak.log
fi
#删除以前的备份
if [ $((${week}-2)) -gt 0 ];
then
    if [ -d ${year}_$((${week}-2)) ];
    then
        rm -rf ${year}_$((${week}-2))
        echo "remove the week before wait week backup file" >> $basedir/bak.log
    else
        :
    fi
else
    rm -rf $(ls $((${year}-1))_*|sed 1p)
    echo "remove the week before wait week backup file" >> $basedir/bak.log
fi
