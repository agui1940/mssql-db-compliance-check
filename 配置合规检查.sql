/*#############################################
# 生产数据库合规性检查
#
# Author:JiangWei
# Date:2016-9-21
##############################################*/
USE master;
GO
SET NOCOUNT ON;
/*
检查项目
1,获取服务器和SQL Server信息;
2,获取SQL Server实例参数信息，注意检查"max server memory (MB)"，例如64GB内存建议配置6?GB;
*/
DECLARE @string NVARCHAR(MAX) ,
    @cores INT ,
    @physical_menory INT ,
    @config_menory NVARCHAR(10);

PRINT '开始检查内存配置......';

SELECT  @cores = cpu_count ,
        @physical_menory = physical_memory_kb / 1024
FROM    sys.dm_os_sys_info;

SELECT  @config_menory = CAST(value AS NVARCHAR(10))
FROM    sys.configurations
WHERE   name = 'max server memory (MB)';

PRINT '	SERVER NAME:	' + CONVERT(NVARCHAR(50), SERVERPROPERTY('ServerName'));
PRINT '	SQL SERVER:	' + CONVERT(NVARCHAR(50), SERVERPROPERTY('Edition'))
    + '	' + CONVERT(NVARCHAR(50), SERVERPROPERTY('ProductVersion')) + '	'
    + CONVERT(NVARCHAR(50), SERVERPROPERTY('ProductLevel'));
PRINT '	CPU cores:	' + CAST(@cores AS NVARCHAR(5))
    + '	physical memeory (MB):' + CAST(@physical_menory AS NVARCHAR(5));
PRINT '	max server memory (MB):	' + @config_menory + 'MB';
IF @config_menory > @physical_menory
    BEGIN
        PRINT '	***********警告!	SQL内存配置数量大于物理内存数量!!!';
    END;
/*
检查项目
1,用户数据库兼容级别应与系统数据库相同;
2,生产数据库恢复模式应为"FULL";
3,归档数据库恢复模式应为"Simple";
*/
DECLARE @compatibility_stand TINYINT ,
    @int TINYINT ,
    @compatibility_level TINYINT ,
    @db_name NVARCHAR(50) ,
    @recovery_model NVARCHAR(10);
SET @int = 6;

PRINT '';
PRINT '开始检查用户数据库兼容级别和备份模式......';

SELECT  @compatibility_stand = compatibility_level
FROM    sys.databases
WHERE   database_id = 1;

WHILE @int <= ( SELECT  MAX(database_id)
                FROM    sys.databases
              )
    BEGIN
        SELECT  @db_name = name ,
                @compatibility_level = compatibility_level ,
                @recovery_model = recovery_model_desc
        FROM    sys.databases
        WHERE   database_id = @int;
        IF @compatibility_level < @compatibility_stand
            BEGIN
                PRINT '	***********警告!	数据库:' + @db_name + ' 兼容级别与当前服务器实例'
                    + CAST(@compatibility_stand AS NVARCHAR(5)) + '不符!!!';
            END;
        IF @recovery_model <> 'FULL'
            BEGIN
                PRINT '	***********注意!	数据库:' + @db_name + ' 恢复模式'
                    + @recovery_model + '不为完整!!!';
            END;
        SET @int = @int + 1;
    END;
/*
检查项目
1.tempdb数据文件应该为8;
2.系统数据库的目录应该位于F:\DATA\;
3.用户数据库初始大小和增长情况？开启自动增长，增长率为10%;
*/
DECLARE @db_id INT ,
    @name NVARCHAR(50) ,
    @physical_name NVARCHAR(500) ,
    @growth INT ,
    @is_percent_growth INT;

PRINT '';
PRINT '开始检查tempdb数量......';

IF ( SELECT COUNT(0)
     FROM   sys.master_files
     WHERE  database_id = 2
            AND type = 0
   ) <> 88
    BEGIN
        PRINT '	***********注意!	实例tempdb数量不为88!!!';
    END;

PRINT '';
PRINT '开始检查数据库文件路径和增长......';        
DECLARE db_file CURSOR
FOR
    SELECT  database_id ,
            DB_NAME(database_id) AS db_name ,
            name ,
            physical_name ,
            growth ,
            is_percent_growth
    FROM    master.sys.master_files
    WHERE   database_id <> 5;
OPEN db_file;
FETCH NEXT FROM db_file INTO @db_id, @db_name, @name, @physical_name, @growth,
    @is_percent_growth;
WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @db_id < 5
            BEGIN
                IF @physical_name NOT LIKE 'F:\DATA\System\%'
                    PRINT '	***********警告!	数据库:' + @db_name + ' ' + @name
                        + ' 文件路径不合规 (' + @physical_name + ') !!!';
                IF @is_percent_growth <> 1
                    PRINT '	***********警告!	数据库:' + @db_name + ' ' + @name
                        + ' 文件不是按百分比增长 !!!';
                IF @growth <> 10
                    PRINT '	***********警告!	数据库:' + @db_name + ' ' + @name
                        + ' 文件增长百分比不为10% !!!';
            END;
        ELSE
            BEGIN
                IF @physical_name NOT LIKE 'F:\DATA\%'
                    PRINT '	***********警告!	数据库:' + @db_name + ' ' + @name
                        + ' 文件路径不合规 (' + @physical_name + ') !!!';
                IF @is_percent_growth <> 1
                    PRINT '	***********警告!	数据库:' + @db_name + ' ' + @name
                        + ' 文件不是按百分比增长 !!!';
                IF @growth <> 10
                    PRINT '	***********警告!	数据库:' + @db_name + ' ' + @name
                        + ' 文件增长百分比不为10% !!!';
            END;
        FETCH NEXT FROM db_file INTO @db_id, @db_name, @name, @physical_name,
            @growth, @is_percent_growth;
    END;
CLOSE db_file;
DEALLOCATE db_file;











