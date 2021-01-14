-- Find the prooduct types you need
SELECT DISTINCT 
       ps.ProductShapeCode + pt.Section
FROM dbo.Stock s
     JOIN dbo.Product p ON s.ProductId = p.ProductId
     JOIN dbo.ProductType pt ON p.ProductTypeId = pt.ProductTypeId
     JOIN dbo.ProductShape ps ON pt.ProductShapeId = ps.ProductShapeId
     JOIN ProductShapeType pst ON pst.ProductShapeTypeId = ps.ProductShapeTypeId
     JOIN dbo.Warehouse w ON s.WarehouseId = w.WarehouseId
WHERE pst.ProductShapeTypeName = 'Long'
      AND w.WarehouseCode = 'SDUD'
      AND s.IsAvailable = 1;


BEGIN TRANSACTION;

-- Declare variables
DECLARE @WarehouseCode VARCHAR(50)= 'SDUD';
DECLARE @MachineClassCode VARCHAR(50)= 'Saw';
DECLARE @DefaultSawAllowanceMillimetres INT= 5;

-- Declare other variables
DECLARE @FromDate DATETIME2= SYSDATETIME();
DECLARE @Username VARCHAR(100)= (SELECT TOP 1 Username FROM UserAccount WHERE [Name] LIKE '%Yaroshenko%');
DECLARE @ProductTypeTable TABLE(ProductType VARCHAR(100));

-- Find values to insert
INSERT INTO @ProductTypeTable(ProductType)
       SELECT DISTINCT 
              ps.ProductShapeCode + pt.Section
       FROM dbo.Stock s
            JOIN dbo.Product p ON s.ProductId = p.ProductId
            JOIN dbo.ProductType pt ON p.ProductTypeId = pt.ProductTypeId
            JOIN dbo.ProductShape ps ON pt.ProductShapeId = ps.ProductShapeId
            JOIN ProductShapeType pst ON pst.ProductShapeTypeId = ps.ProductShapeTypeId
            JOIN dbo.Warehouse w ON s.WarehouseId = w.WarehouseId
       WHERE pst.ProductShapeTypeName = 'Long'
             AND w.WarehouseCode = @WarehouseCode
             AND s.IsAvailable = 1;

-- Insert values into processing profile
BEGIN
    DECLARE @CursorProductType VARCHAR(100);
    DECLARE ProcessingProfileCursor CURSOR
    FOR SELECT ProductType
        FROM @ProductTypeTable;
    OPEN ProcessingProfileCursor;
    FETCH NEXT FROM ProcessingProfileCursor INTO @CursorProductType;
    WHILE @@FETCH_STATUS = 0
        BEGIN
            PRINT 'EXEC with product type' + ' - ' + @CursorProductType;
            EXECUTE [Utilities].[UpdateProcessingProfile] 
                    @ProductTypeCode = @CursorProductType, 
                    @WarehouseCode = @WarehouseCode, 
                    @MachineClassCode = @MachineClassCode, 
                    @Username = @Username, 
                    @DefaultSawAllowanceMillimetres = @DefaultSawAllowanceMillimetres;
            FETCH NEXT FROM ProcessingProfileCursor INTO @CursorProductType;
        END;
    CLOSE ProcessingProfileCursor;
    DEALLOCATE ProcessingProfileCursor;
END;

ROLLBACK TRANSACTION;