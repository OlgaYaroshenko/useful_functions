USE [Anvil_NZL]
GO

/****** Object:  StoredProcedure [Utilities].[UpdateProcessingProfile]    Script Date: 16/11/2020 10:22:51 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [Utilities].[UpdateProcessingProfile]
(@ProductTypeCode                  VARCHAR(50),
 @WarehouseCode                    VARCHAR(50),
 @MachineClassCode                 VARCHAR(50),
 @Username                         VARCHAR(50),
 @CustomerCode                     VARCHAR(50)    = NULL,
 @HandlingPerTon                   MONEY          = NULL,
 @CuttingCharge                    MONEY          = NULL,
 @BeveledCuttingCharge             MONEY          = NULL,
 @DrillingPerHole                  MONEY          = NULL,
 @CountersunkPerHole               MONEY          = NULL,
 @PerPierce                        MONEY          = NULL,
 @CopingPerCut                     MONEY          = NULL,
 @DefaultScrapAllowanceMillimetres INT            = NULL,
 @DefaultYieldLossPercentage       DECIMAL(18, 5) = NULL,
 @DefaultSawAllowanceMillimetres   INT            = NULL,
 @HandlingPerTonCost               MONEY          = NULL,
 @CuttingCost                      MONEY          = NULL,
 @BeveledCuttingCost               MONEY          = NULL,
 @DrillingPerHoleCost              MONEY          = NULL,
 @CountersunkPerHoleCost           MONEY          = NULL,
 @PerPierceCost                    MONEY          = NULL,
 @FoldingPerPartCost               MONEY          = NULL,
 @CopingPerCutCost                 MONEY          = NULL
)
AS
     SET NOCOUNT ON;
     SET DEADLOCK_PRIORITY LOW;
     -- ==============================================================
     -- Created by: Olga Y
     -- Created date: 12.10.2020
     -- ==============================================================

     DECLARE @NewFromDate DATETIME2 = SYSDATETIME();
     DECLARE @ToDate DATETIME2 = @NewFromDate;

    BEGIN TRY
        BEGIN TRANSACTION UpdateProcessingProfile;

        DECLARE @ProductTypeId INT= (
        SELECT ProductTypeId
        FROM ProductTypeShapeCategoryView AS PTSCV
        WHERE PTSCV.ProductTypeCode = @ProductTypeCode);
        IF @ProductTypeId IS NULL
            THROW 51000, 'The product type is incorrect or does not exist.', 1;

        DECLARE @WarehouseId INT= (
        SELECT TOP 1 w.WarehouseId
        FROM dbo.Warehouse w
        WHERE w.WarehouseCode = @WarehouseCode);
        IF @WarehouseId IS NULL
            THROW 51000, 'The warehouse is incorrect or does not exist.', 1;

        DECLARE @MachineClassId INT= (
        SELECT TOP 1 mc.MachineClassId
        FROM Production.MachineClass mc
        WHERE mc.MachineClassCode = @MachineClassCode);
        IF @MachineClassId IS NULL
            THROW 51000, 'The machine class is incorrect or does not exist.', 1;

        IF(@CustomerCode IS NOT NULL
           AND @CustomerCode != '')
            BEGIN
                DECLARE @CustomerId INT= (
                SELECT TOP 1 c.CustomerId
                FROM dbo.Customer c
                WHERE c.CustomerCode = @CustomerCode);
                IF @CustomerId IS NULL
                    THROW 51000, 'The customer is incorrect or does not exist.', 1;
            END;

        DECLARE @UserId INT= (
        SELECT TOP 1 ua.UserId
        FROM dbo.UserAccount ua
        WHERE ua.Username = @Username);
        IF @UserId IS NULL
            THROW 51000, 'The user name is incorrect or does not exist.', 1;

        --check if there is another default profile, could be on different machine
        DECLARE @OtherDefault BIT= (
        SELECT TOP 1 pp.IsDefault
        FROM Production.ProcessingProfile pp
        WHERE pp.ProductTypeId = @ProductTypeId
              AND pp.WarehouseId = @WarehouseId
              AND pp.CustomerId = @CustomerId
              AND pp.IsDefault = 1);

        DECLARE @ProcessingProfiles AS TABLE
        (ProductTypeId       INT,
         WarehouseId         INT,
         ProcessingProfileId INT,
         IsDefault           BIT,
         MachineClassId      INT,
         CustomerId          INT
        );

        INSERT INTO @ProcessingProfiles
               SELECT pt.ProductTypeId,
                      @WarehouseId,
                      pp.ProcessingProfileId,
                      pp.IsDefault,
                      pp.MachineClassId,
                      pp.CustomerId
               FROM ProductType pt
                    LEFT OUTER JOIN Production.ProcessingProfile pp ON pp.ProductTypeId = pt.ProductTypeId
                                                                       AND pp.WarehouseId = @WarehouseId
                                                                       AND pp.IsActiveProfile = 1
                                                                       AND pp.MachineClassId = @MachineClassId
                                                                       AND (pp.CustomerId = @CustomerId
                                                                            OR (pp.CustomerId IS NULL
                                                                                AND @CustomerId IS NULL))
               WHERE pt.ProductTypeId = @ProductTypeId;

        PRINT 'EXISTING PROFILE';
        SELECT *
        FROM @ProcessingProfiles pp
        WHERE ProcessingProfileId IS NOT NULL;

        PRINT 'NEW PROFILE';
        SELECT *
        FROM @ProcessingProfiles pp
        WHERE ProcessingProfileId IS NULL;

        PRINT 'RETIRE THE EXISTING PROFILE';
        UPDATE pp
          SET
              pp.[ToDate] = @ToDate,
              pp.[IsDefault] = 0,
              pp.[ProcessingProfileModifiedByUserId] = @UserId
        FROM Production.ProcessingProfile pp
             JOIN @ProcessingProfiles newPP ON pp.ProcessingProfileId = newPP.ProcessingProfileId;

        PRINT 'INSERT THE NEW ONE';
        INSERT INTO Production.ProcessingProfile
        ([ProductTypeId],
         [WarehouseId],
         [MachineClassId],
         [HandlingPerTon],
         [CuttingCharge],
         [BeveledCuttingCharge],
         [DrillingPerHole],
         [CountersunkPerHole],
         [PerPierce],
         [CopingPerCut],
         [HandlingPerTonCost],
         [CuttingCost],
         [BeveledCuttingCost],
         [DrillingPerHoleCost],
         [CountersunkPerHoleCost],
         [PerPierceCost],
         [FoldingPerPartCost],
         [CopingPerCutCost],
         [FromDate],
         [ToDate],
         [DefaultScrapAllowanceMillimetres],
         [DefaultYieldLossPercentage],
         [DefaultSawAllowanceMillimetres],
         [ProcessingProfileModifiedByUserId],
         [CustomerId],
         [IsDefault]
        )
               SELECT @ProductTypeId,
                      @WarehouseId,
                      @MachineClassId,
                      COALESCE(@HandlingPerTon, pp.HandlingPerTon, 0),
                      COALESCE(@CuttingCharge, pp.CuttingCharge, 0),
                      COALESCE(@BeveledCuttingCharge, pp.BeveledCuttingCharge, 0),
                      COALESCE(@DrillingPerHole, pp.DrillingPerHole, 0),
                      COALESCE(@CountersunkPerHole, pp.CountersunkPerHole, 0),
                      COALESCE(@PerPierce, pp.PerPierce, 0),
                      COALESCE(@CopingPerCut, pp.CopingPerCut, 0),
                      COALESCE(@HandlingPerTonCost, pp.HandlingPerTonCost, 0),
                      COALESCE(@CuttingCost, pp.CuttingCost, 0),
                      COALESCE(@BeveledCuttingCost, pp.BeveledCuttingCost, 0),
                      COALESCE(@DrillingPerHoleCost, pp.DrillingPerHoleCost, 0),
                      COALESCE(@CountersunkPerHoleCost, pp.CountersunkPerHoleCost, 0),
                      COALESCE(@PerPierceCost, pp.PerPierceCost, 0),
                      COALESCE(@FoldingPerPartCost, pp.FoldingPerPartCost, 0),
                      COALESCE(@CopingPerCutCost, pp.CopingPerCutCost, 0),
                      @NewFromDate, -- from date
                      NULL, -- to date
                      COALESCE(@DefaultScrapAllowanceMillimetres, pp.DefaultScrapAllowanceMillimetres, 0),
                      COALESCE(@DefaultYieldLossPercentage, pp.DefaultYieldLossPercentage, 0),
                      COALESCE(@DefaultSawAllowanceMillimetres, pp.DefaultSawAllowanceMillimetres, 0),
                      @UserId,
                      @CustomerId,
                      COALESCE(exPP.IsDefault, CASE WHEN @OtherDefault = 1 THEN 0 ELSE 1 END)
               FROM @ProcessingProfiles exPP
                    LEFT OUTER JOIN Production.ProcessingProfile pp ON pp.ProcessingProfileId = exPP.ProcessingProfileId;

        SELECT *
        FROM Production.ProcessingProfile pp
        WHERE pp.ProductTypeId = @ProductTypeId
              AND pp.WarehouseId = @WarehouseId
              AND pp.ToDate IS NULL;

        COMMIT TRANSACTION UpdateProcessingProfile;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION UpdateProcessingProfile;
        THROW;
    END CATCH;
GO


