USE [Anvil_NZL]
GO

/****** Object:  StoredProcedure [Utilities].[ProductType_CreateNew]    Script Date: 16/11/2020 10:21:11 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [Utilities].[ProductType_CreateNew]
(@ProductGroupName                 VARCHAR(50),
 @ProductShapeCode                 VARCHAR(50),
 @Section                          VARCHAR(50),
 @Thickness                        DECIMAL(18, 5),
 @SQMPerTON                        DECIMAL(18, 5),
 @Height                           DECIMAL(18, 5),
 @Width                            DECIMAL(18, 5),
 @Description                      VARCHAR(50),
 @TestCertificateOptionId          INT            = 2, -- 2 - Not Required
 @Size                             VARCHAR(50),
 @KilogramsPerMetre                DECIMAL(18, 5),
 @MachineClassCode                 VARCHAR(50),
 @CanSellPartialSerialisedStock    BIT            = 0,
 @DefaultScrapAllowanceMillimetres INT            = 0,
 @DefaultYieldLossPercentage       DECIMAL(18, 5) = 0,
 @DefaultSawAllowanceMillimetres   INT            = 0
)
AS
     SET NOCOUNT ON;
     SET DEADLOCK_PRIORITY LOW;

    BEGIN TRY
        BEGIN TRANSACTION ProductType_CreateNew;

        DECLARE @ProductGroupId INT= (SELECT TOP 1 ProductGroupId FROM ProductGroup WHERE ProductGroupName = @ProductGroupName);
        IF @ProductGroupId IS NULL THROW 51000, 'The product group is incorrect or does not exist.', 1;

        DECLARE @ProductShapeId INT= (SELECT TOP 1 ProductShapeId FROM ProductShape WHERE ProductShapeCode = @ProductShapeCode);
        IF @ProductShapeId IS NULL THROW 51000, 'The product shape is incorrect or does not exist.', 1;

        DECLARE @MachineClassId INT= (SELECT TOP 1 MachineClassId FROM [Production].[MachineClass] WHERE MachineClassCode = @MachineClassCode);

        DECLARE @ProductShapeTypeName VARCHAR(50)= (SELECT ProductShapeTypeName FROM ProductShape ps
            JOIN ProductShapeType pst ON pst.ProductShapeTypeId = ps.ProductShapeTypeId WHERE ProductShapeId = @ProductShapeId);

        IF(@ProductShapeTypeName IN('Plate', 'Coil') AND @SQMPerTON <= 0.0000) THROW 51000, 'SQM must be greater than zero for Plate or Coil', 1;
        IF(@ProductShapeTypeName IN('Plate', 'Coil') AND @Thickness <= 0.0000) THROW 51000, 'Thickness must be greater than zero for Plate or Coil', 1;
        IF(@ProductShapeTypeName IN('Long') AND (@Height <= 0.00 OR @Width <= 0.00)) THROW 51000, 'You need a height and width for long products', 1;
        IF(@Section LIKE('%+%')) THROW 51000, 'Leave the plus sign out of the section.', 1;

        INSERT INTO [dbo].[ProductType]
        ([ProductShapeId],
         [ProductGroupId],
         [Section],
         [Thickness],
         [SquareMetresPerTonne],
         [Height],
         [Width],
         [Description],
         [TestCertificateOptionId],
         [Size],
         [KilogramsPerMetre],
         [CanSellPartialSerialisedStock]
        )
        VALUES
        (@ProductShapeId,
         @ProductGroupId,
         @Section,
         @Thickness,
         @SQMPerTON,
         @Height,
         @Width,
         @Description,
         @TestCertificateOptionId,
         @Size,
         @KilogramsPerMetre,
         CASE WHEN @ProductShapeTypeName = 'Coil' THEN @CanSellPartialSerialisedStock ELSE 0 END);

        -- select all warehouses which have plate and long machine classes
        DECLARE @WarehouseHasLongAndPlateMachineClassCode TABLE
        ( WarehouseCode  VARCHAR(50) );

        INSERT INTO @WarehouseHasLongAndPlateMachineClassCode (WarehouseCode)
               SELECT DISTINCT w.WarehouseCode
               FROM [Production].[Machine] m
                    JOIN Warehouse w ON m.WarehouseId = w.WarehouseId
                    JOIN [Production].MachineClass mc ON mc.MachineClassId = m.MachineClassId
               WHERE w.IsActive = 1
                     AND m.IsActive = 1
                     AND (mc.ProductShapeType = 'Plate' OR mc.ProductShapeType = 'Long')
                     AND mc.MachineClassCode = @MachineClassCode

        IF(@ProductShapeTypeName = 'Plate' OR @ProductShapeTypeName = 'Long')
            BEGIN
                DECLARE @FromDate DATETIME2= SYSDATETIME();
                DECLARE @Username VARCHAR(100)= (SELECT TOP 1 Username FROM UserAccount WHERE [Name] LIKE '%Admin%');
                DECLARE @ProductTypeCode VARCHAR(100)= @ProductShapeCode + @Section;
                DECLARE @CursorWarehouseCode VARCHAR(50);

                DECLARE ProcessingProfileCursor CURSOR
                FOR SELECT WarehouseCode
                    FROM @WarehouseHasLongAndPlateMachineClassCode;
                OPEN ProcessingProfileCursor;

                FETCH NEXT FROM ProcessingProfileCursor INTO @CursorWarehouseCode;
                WHILE @@FETCH_STATUS = 0
                    BEGIN
                        PRINT 'EXEC with warehouse' + ' - ' + @CursorWarehouseCode
                        EXECUTE [Utilities].[UpdateProcessingProfile]
                           @ProductTypeCode
                          ,@CursorWarehouseCode
                          ,@MachineClassCode
                          ,@Username
                          ,NULL
                          ,NULL
                          ,NULL
                          ,NULL
                          ,NULL
                          ,NULL
                          ,NULL
                          ,NULL
                          ,@DefaultScrapAllowanceMillimetres
                          ,@DefaultYieldLossPercentage
                          ,@DefaultSawAllowanceMillimetres
                          ,NULL
                          ,NULL
                          ,NULL
                          ,NULL
                          ,NULL
                          ,NULL
                          ,NULL
                          ,NULL
                        FETCH NEXT FROM ProcessingProfileCursor INTO @CursorWarehouseCode;
                    END;
                CLOSE ProcessingProfileCursor;
                DEALLOCATE ProcessingProfileCursor;
            END;
        COMMIT TRANSACTION ProductType_CreateNew;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION ProductType_CreateNew;
        THROW;
    END CATCH;
GO


