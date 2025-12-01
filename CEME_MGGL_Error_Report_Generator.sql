USE [AribaDB]
GO
 
/****** Object:  StoredProcedure [dbo].[CEME_MGGL_File_ErrorReport_Generator]    Script Date: 9/8/2024 1:45:31 AM ******/
SET ANSI_NULLS ON
GO
 
SET QUOTED_IDENTIFIER ON
GO
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
CREATE DATE:
1st of December, 2023 by Hameed Nowfal Sulaiman
 
Description:
 
This Stored Procedure is used to evaluate the "Material Group - Account Category - General Ledger Mapping" data provided in design document by customer and generate CEME and MG-GL Relation entry files for valid entries and an error report for invalid entries.

It containes the SELECT Query to generate the Commodity Export Map Export (CEME) and MGGL Relation Entry files and their error Report.
 
Input Parameters:
 
It takes the below Parameters as Inputs:
1. @GAR_Country_ID -> The Country ID of the Company Codes for GAR file Validation.
    a. Input must be given in single quotes.
    b. Example input: 'IN' 
2. @CompanyCode_Column_BUKRS_Or_FSTVA -> The column from CompanyCodeobject which must be used as filter.
    a. Input must be given in single quotes.
    b. Input can either be 'FSTVA'(if file is needed for entire Country) or 'BUKRS'(if file is needed for selected Companycodes of the Country)
3. @CompanyCode_Value_IDs_Or_Variants -> The corresponding value related to @CompanyCode_Column_BUKRS_Or_FSTVA
    a. If @CompanyCode_Column_BUKRS_Or_FSTVA is 'FSTVA', then this field must have valid Country's variant.
    b. If @CompanyCode_Column_BUKRS_Or_FSTVA is 'BUKRS', then this field must have valid Country's CompanyCode.
4. @Need_Counts_Check -> If additional Counts check need to be performed for extra validation.
    a. Value given must be 'Yes' for this validation to be done.
 
Pre-Requisites before Executing the Stored Procedure:
 
1. The Following 10 Tables must be created in the DB which is used and the Latest Data from the Ariba Instance should be Loaded in them:
 
|-------|-----------------------------------|-------------------------------------------------------|
|No.    |Tables_Name                        |Data_Source                                            |
|-------|-----------------------------------|-------------------------------------------------------|
|1.     |"CompanyCodeExport"                |Exported from Ariba SAP Partition Realm                |
|2.     |"GeneralLedgerExport"              |Exported from Ariba SAP Partition Realm                |
|3.     |"AccountTypeExport"                |Exported from Ariba SAP Partition Realm                |
|4.     |"AccountCategoryExport"            |Exported from Ariba SAP Partition Realm                |
|5.     |"PartitionedCommodityCodeExport"   |Exported from Ariba SAP Partition Realm                |
|6.     |"MGGLComboExport"                  |Exported from Ariba SAP Partition Realm                |
|7.     |"GAR_RULES"                        |Obtained from SAP ERP                                  |
|8.     |"MG_PG"                            |"MG-PG" mapping defined in SAP ERP                     |
|9.     |"MG_GT"                            |"MG-GTCode" mapping defined in SAP ERP                 |
|10.    |"MG_AC_GL_Map"                     |"MG-GL Mapping" given in Design Document by client     |
|-------|-----------------------------------|-------------------------------------------------------|
 
2.    Above 10 Tables must be created with the EXACT TABLE NAMES as mentioned above.

3.    COLUMN NAMES for above tables(except "MG_AC_GL_Map") should be exactly same as the column names(including spaces, special characters etc.) in their Source Files with DataType "NVARCHAR(LEN)". Where "LEN" is Appropriate Length as required or "MAX"

4.    For the Last Table "MG_AC_GL_Map", the Column names must be as per the below CREATE Query:
        CREATE TABLE "MG_AC_GL_Map"(
			"MG" NVARCHAR(10),
			"Account" NVARCHAR(50),
			"Preferred" NVARCHAR(10),
			"GL" NVARCHAR(15),
			"Default" NVARCHAR(10),
			"Amt_Rec" NVARCHAR(10),
        );

5.    Load the Latest Data from the System/Data_Source including MG-GL Mapping From Design Document in the form of .csv files with Line Ending: "\n"(UNIX) and Encoding: "UTF-8".
    For Example:
        BULK INSERT MG_AC_GL_Map
        FROM 'C:\Users\...\MG_AC_GL_Map.csv'
        WITH
        (
                FIELDTERMINATOR = ',',
                ROWTERMINATOR = '0x0a',        --- Hexadecimal notation for line feed (LF) row terminator which is the ASCII newline character "\n"
                CODEPAGE = '65001',            --- 65001 is the Windows code page identifier for UTF-8
                FORMAT='CSV',                
                FIRSTROW=2                    --- To Ignore the 1st row having column Names
        );
6.    Now the Procedure can be successfully Created(if not already) and Exceuted.
 
Output File content:
 
1.    The first Column "ERROR_Columns", gives the concatenated value of all the Validation Columns which has error.
2.    The Next 6 columns of the Output File gives the "MG_AC_GL_Map" Table values obtained from Design Document.
3.    Followed by MGGL Relation Entries File Data and CEME File Data.
4.    Validation Columns: The Output file contains the below list of columns each shows the validation done over the "MG_AC_GL_Map" Table:
 
    A.  Invalid values which may be entered in BBS (Validation for Data entered by Member Firm):
        01. Valid MG?                                       ->    Checks if Entered MG is present in PartiionedCommodityCode Master Data
        02. Valid AccountType?                              ->    Checks if Entered AC is present in AccountType Master Data
        03. Valid MG Preference?                            ->    Checks if Entered value is either 'Yes'/'No' or otherwise
        04. Valid GL Defaulting?                            ->    Checks if Entered value is either 'Yes'/'No' or otherwise
        05. Valid ReceiveByAmount Preference?               ->    Checks if Entered value is either 'Yes'/'No' or otherwise
        06. Duplicate Row(s) exist?                         ->    Checks if any row is completely a Duplicate copy of another row
        07. Preferred AC >1 for any MG(s)?                  ->    Checks if any MG has more than one Preferred AC
        08. No Preferred AC for any MG(s)?                  ->    Checks if any MG has No Preferred AC at all
        09. Contradicting AC Preference for any MG(s)?      ->    Checks if any MG has an AC marked as both Yes as well as No
        10. Contradicting Amt_Rec Preference for any MG(s)? ->    Checks if any MG-AC combo was given both Yes as well as No for Receive By Amount
        11. Default GL<>1 for any MG-AC combo(s)?           ->    Checks if any MG-AC combo was given more than one or exactly one or no Default GL
        12. Duplicate GL in any MG-AC Combo(s)?             ->    Checks if any MG-AC combo was mapped to a GL more than once
 
    B.  Absence of internally maintained mapping Data (Validation for Internal Data):
        13. Valid PG Mapping Present for MG?                ->    Checks if all MGs have a valid Purchase Group(PG) mapped in SAP ERP
        14. Valid GTCode Mapping Present for MG?            ->    Checks if all MGs have a valid Global Taxonomy(GT) Code/CommodityCode mapped in SAP ERP
 
    C.  External/Peer system Data related validations (MDG Related and GAR File Validation):
        15. Valid GAR-entry?                                ->    Checks if All the GLs for the given Member Firm are present in GAR Table with AP entry and atleast one WBS type allowed or not
        16. Valid MGGL Combo as per MGGL FMD?               ->    Checks if all the MG-GL combos given in BBS are present in the Global MG-GL combo data obtained from Flex Masted Data or not
        17. Valid CC-GL combo?                              ->    Checks if all the Companycode-GL Mapping present in CEME/MGGL file generated are present in GeneralLedger Master Data or not
 
5.    Counts Check Entries: In addition to above Row by Row validations, the Output file contains list of consolidated count based validation results. These count checks are performed for an additional/optional confirmation to make sure no discrepancy is failed to be captured.
 
    A.  Counts to check presence of Duplicate entries:
        01. All BBS Entries                                 ->    Count of total Line in Design Document's MG-GL Mapping Tab
        02. Distinct BBS Entries                            ->    Count of Distinct entries in Design Document's MG-GL Mapping Tab
        03. Duplicates in MG_AC_GL_Map?                     ->    Shows if there's any Duplicate entry in Design Document's MG-GL Mapping Tab or not
 
    B.  Counts to check contradictory AC and ReceiveByAmount Preference: 
        04. Distinct MGs in BBS                             ->    Count of Distinct MGs in Design Document's MG-GL Mapping Tab
        05. Distinct MG-AC Combos in BBS                    ->    Count of Distinct MG-AC Combos in Design Document's MG-GL Mapping Tab
        06. Distinct MG-AC-Preference Combos in BBS         ->    Count of Distinct MG-AC-Preferrence Combos in Design Document's MG-GL Mapping Tab
        07. Contradiction in AC Preference?                 ->    Shows if for any MG, an AC is marked as both 'Yes' and 'No' in Preferred column in Design Document's MG-GL Mapping Tab or not
        08. Distinct MG-AC-ReceiveByAmount Combos in BBS    ->    Count of Distinct MG-AC-ReceiveByAmount Combos in Design Document's MG-GL Mapping Tab
        09. Contradiction in ReceiveByAmount Preference?    ->    Shows if any MG-AC combo is chosen as both 'Yes' AND 'No' for ReceiveByAmount or not
 
    C.  Counts to check Presence of MGs with more than one AND/OR with No Preferred Account Categories:
        10. Distinct MGs in BBS having Preferred AC(s)                    ->    Count of Distinct MGs in Design Document's MG-GL Mapping Tab having Preferred AC(s)
        11. Distinct MG-AC combo in BBS having Preferred AC(s)            ->    Count of Distinct MG-AC Combos in Design Document's MG-GL Mapping Tab having Preferred AC(s)
        12. Presence of MGs with 0 or >1 Preferred AC(s) or Both          ->    Shows is there are any MGs with more than one AND/OR with No Preferred Account Categories or not
 
    D.  Counts to check Presence of MG-AC combos with more than one AND/OR with No Default GLs:
        13. Contradiction in GL Default?                                  ->    Shows if for any MG-AC Combo, a GL is marked as both 'Yes' and 'No' in Default column in Design Document's MG-GL Mapping Tab or not
        14. Distinct MGs in BBS having Preferred AC(s) and Default GL(s)  ->    Count of all Distinct MGs in Design Document's MG-GL Mapping Tab having a Preferred AC and a Default GL
        15. Presence of MG-AC Combos with 0 or >1 Default GL(s) or Both   ->    Shows is there are any MG-AC Combos with more than one AND/OR with No Default GL or not
 
*/
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 
ALTER PROCEDURE [dbo].[CEME_MGGL_File_ErrorReport_Generator] 
    @GAR_MemberFirm_ID NVARCHAR(50),
    --@CompanyCode_Value_IDs_Or_Variants NVARCHAR(MAX),
    --@CompanyCode_Column_BUKRS_Or_FSTVA NVARCHAR(MAX),
    @Need_Counts_Check NVARCHAR(MAX),
    @Query_For_CompanyCode_List NVARCHAR(MAX)
 
AS
BEGIN
--@CompanyCode_Column_BUKRS_Or_FSTVA NVARCHAR(MAX),
--@CompanyCode_Filter_Condition NVARCHAR(MAX)
 
CREATE TABLE #Temp_CompanyCode_List
(
    BUKRS NVARCHAR(10)
);
 
DECLARE @Insert_BUKRS_Into_Temp_CompanyCode_List NVARCHAR(MAX) = 'INSERT INTO #Temp_CompanyCode_List (BUKRS)'+@Query_For_CompanyCode_List;
 
EXEC sp_executesql @Insert_BUKRS_Into_Temp_CompanyCode_List;
 
--- Starting to Update the Values of AC Preferrence and GL Defaulting FROM 'Yes' and 'No' TO '1' and '0' respectively for validating purpose --------
 
UPDATE "MG_AC_GL_Map" SET "Preferred" = '1' WHERE "Preferred" = 'Yes';
UPDATE "MG_AC_GL_Map" SET "Preferred" = '0' WHERE "Preferred" = 'No';
UPDATE "MG_AC_GL_Map" SET "Default" = '1' WHERE "Default" = 'Yes';
UPDATE "MG_AC_GL_Map" SET "Default" = '0' WHERE "Default" = 'No';
 
--- Finished Updating the Values of AC Preferrence and GL Defaulting FROM 'Yes' and 'No' TO '1' and '0' respectively for validating purpose --------
 
--- Starting to Declare and Assign values to Parameters for performing overall Count based Checks ------
IF @Need_Counts_Check = 'Yes'
BEGIN
 
DECLARE
 
        @All_BBS_Entries INT = (SELECT COUNT(*) FROM "MG_AC_GL_Map"),
        @All_Distinct_BBS_Entires INT = (SELECT COUNT(DISTINCT CONCAT("MG_AC_GL_Map"."MG",'-',"MG_AC_GL_Map"."AC",'-',"MG_AC_GL_Map"."Preferred",'-',"MG_AC_GL_Map"."GL",'-',"MG_AC_GL_Map"."Default",'-',"MG_AC_GL_Map"."Amt_Rec") ) FROM "MG_AC_GL_Map"),
 
        @All_Distinct_MGs INT = (SELECT COUNT(DISTINCT "MG_AC_GL_Map"."MG") FROM "MG_AC_GL_Map"),
        @All_Distinct_MG_AC_Combos INT = (SELECT COUNT(DISTINCT CONCAT("MG_AC_GL_Map"."MG",'-',"MG_AC_GL_Map"."AC")) FROM "MG_AC_GL_Map"),
        @All_Distinct_MG_AC_Preferred_Combos INT = (SELECT COUNT(DISTINCT CONCAT("MG_AC_GL_Map"."MG",'-',"MG_AC_GL_Map"."AC",'-',"MG_AC_GL_Map"."Preferred")) FROM "MG_AC_GL_Map"),
        @All_Distinct_MG_AC_GL_Combos INT = (SELECT COUNT(DISTINCT CONCAT("MG_AC_GL_Map"."MG",'-',"MG_AC_GL_Map"."AC",'-',"MG_AC_GL_Map"."GL")) FROM "MG_AC_GL_Map"),
        @All_Distinct_MG_AC_GL_Default_Combos INT = (SELECT COUNT(DISTINCT CONCAT("MG_AC_GL_Map"."MG",'-',"MG_AC_GL_Map"."AC",'-',"MG_AC_GL_Map"."GL",'-',"MG_AC_GL_Map"."Default")) FROM "MG_AC_GL_Map"),
        @All_Distinct_MG_AC_Amt_Rec_Combos INT = (SELECT COUNT(DISTINCT CONCAT("MG_AC_GL_Map"."MG",'-',"MG_AC_GL_Map"."AC",'-',"MG_AC_GL_Map"."Amt_Rec")) FROM "MG_AC_GL_Map"),
 
        @All_Distinct_MGs_With_Preferred_AC INT = (SELECT COUNT(DISTINCT "MG_AC_GL_Map"."MG") FROM "MG_AC_GL_Map" WHERE "MG_AC_GL_Map"."Preferred" = '1'),
        @All_Distinct_MG_AC_Combos_With_Preferred_AC INT = (SELECT COUNT(DISTINCT CONCAT("MG_AC_GL_Map"."MG",'-',"MG_AC_GL_Map"."AC")) FROM "MG_AC_GL_Map" WHERE "MG_AC_GL_Map"."Preferred" = '1'),
        @All_Distinct_MG_AC_Preferred_Combos_With_Preferred_AC INT = (SELECT COUNT(DISTINCT CONCAT("MG_AC_GL_Map"."MG",'-',"MG_AC_GL_Map"."AC",'-',"MG_AC_GL_Map"."Preferred")) FROM "MG_AC_GL_Map" WHERE "MG_AC_GL_Map"."Preferred" = '1'),
 
        @All_Distinct_MG_AC_Combos_With_Default_GL INT = (SELECT COUNT(DISTINCT CONCAT("MG_AC_GL_Map"."MG",'-',"MG_AC_GL_Map"."AC")) FROM "MG_AC_GL_Map" WHERE "MG_AC_GL_Map"."Default" = '1'),
        @All_Distinct_MG_AC_GL_Combos_With_Default_GL INT = (SELECT COUNT(DISTINCT CONCAT("MG_AC_GL_Map"."MG",'-',"MG_AC_GL_Map"."AC",'-',"MG_AC_GL_Map"."GL")) FROM "MG_AC_GL_Map" WHERE "MG_AC_GL_Map"."Default" = '1'),
        @All_MGs_With_Preferred_AC_AND_Default_GL INT = (SELECT COUNT("MG_AC_GL_Map"."MG") FROM "MG_AC_GL_Map" WHERE "MG_AC_GL_Map"."Preferred" = '1' AND "MG_AC_GL_Map"."Default" = '1'),
        @All_Distinct_MGs_With_Preferred_AC_AND_Default_GL INT = (SELECT COUNT(DISTINCT "MG_AC_GL_Map"."MG") FROM "MG_AC_GL_Map" WHERE "MG_AC_GL_Map"."Preferred" = '1' AND "MG_AC_GL_Map"."Default" = '1'),
 
        @Duplicates_In_MG_AC_GL_Map_Result NVARCHAR(MAX),
 
        @Contradiction_In_AC_Preference_Result NVARCHAR(MAX),
        @MGs_Have_Only_1_Preferred_AC_Or_Not_Result NVARCHAR(MAX),
 
        @Contradiction_In_GL_Default_Result NVARCHAR(MAX),
        @MG_AC_Combos_Have_Only_1_Default_GL_Or_Not_Result NVARCHAR(MAX),
 
        @Contradiction_In_ReceiveByAmount_Result NVARCHAR(MAX);
 
SET @Duplicates_In_MG_AC_GL_Map_Result =
    CASE
        WHEN
            @All_BBS_Entries = @All_Distinct_BBS_Entires
        THEN ''
        WHEN
            @All_BBS_Entries > @All_Distinct_BBS_Entires
        THEN 'Yes-Duplicates in MG_AC_GL_Map'
        ELSE 'Unknown error'
    END;
 
SET @Contradiction_In_AC_Preference_Result =
    CASE
        WHEN
            @All_Distinct_MG_AC_Combos = @All_Distinct_MG_AC_Preferred_Combos
        THEN ''
        WHEN
            @All_Distinct_MG_AC_Combos < @All_Distinct_MG_AC_Preferred_Combos
        THEN 'AC is marked both Yes/No for some MG(s)'
        ELSE 'Unknown error'
    END;
 
SET @MGs_Have_Only_1_Preferred_AC_Or_Not_Result =
    CASE
        WHEN
            @All_Distinct_MG_AC_Combos <> @All_Distinct_MG_AC_Preferred_Combos
        THEN 'AC Preference Contradiction'
        WHEN
            @All_Distinct_MG_AC_Combos = @All_Distinct_MG_AC_Preferred_Combos
            AND
            @All_Distinct_MGs = @All_Distinct_MGs_With_Preferred_AC
            AND
            @All_Distinct_MGs = @All_Distinct_MG_AC_Combos_With_Preferred_AC
            AND
            @All_Distinct_MGs_With_Preferred_AC = @All_Distinct_MG_AC_Combos_With_Preferred_AC
        THEN ''
        WHEN
            @All_Distinct_MG_AC_Combos = @All_Distinct_MG_AC_Preferred_Combos
            AND
            @All_Distinct_MGs > @All_Distinct_MGs_With_Preferred_AC
            AND
            @All_Distinct_MGs > @All_Distinct_MG_AC_Combos_With_Preferred_AC
            AND
            @All_Distinct_MGs_With_Preferred_AC = @All_Distinct_MG_AC_Combos_With_Preferred_AC
        THEN 'MGs with no Preferred AC exist'
        WHEN
            @All_Distinct_MG_AC_Combos = @All_Distinct_MG_AC_Preferred_Combos
            AND
            @All_Distinct_MGs = @All_Distinct_MGs_With_Preferred_AC
            AND
            @All_Distinct_MGs = @All_Distinct_MG_AC_Combos_With_Preferred_AC
            AND
            @All_Distinct_MGs_With_Preferred_AC < @All_Distinct_MG_AC_Combos_With_Preferred_AC
        THEN 'MGs with >1 Preferred AC exist'
        WHEN
            @All_Distinct_MG_AC_Combos = @All_Distinct_MG_AC_Preferred_Combos
            AND
            @All_Distinct_MGs > @All_Distinct_MGs_With_Preferred_AC
            AND
            @All_Distinct_MGs > @All_Distinct_MG_AC_Combos_With_Preferred_AC
            AND
            @All_Distinct_MGs_With_Preferred_AC < @All_Distinct_MG_AC_Combos_With_Preferred_AC
        THEN 'MGs with Both >1 and 0 Preferred AC exist'
        ELSE 'Unknown Error'
    END;
 
SET @Contradiction_In_GL_Default_Result =
    CASE
        WHEN
            @All_Distinct_MG_AC_GL_Combos = @All_Distinct_MG_AC_GL_Default_Combos
        THEN ''
        WHEN
            @All_Distinct_MG_AC_GL_Combos < @All_Distinct_MG_AC_GL_Default_Combos
        THEN 'GL is marked both Yes/No for some MG-AC Combo(s)'
        ELSE 'Unknown error'
    END;
 
 
SET @MG_AC_Combos_Have_Only_1_Default_GL_Or_Not_Result =
    CASE
        WHEN
            @All_Distinct_MGs = @All_Distinct_MGs_With_Preferred_AC_AND_Default_GL
            AND
            @All_Distinct_MGs = @All_MGs_With_Preferred_AC_AND_Default_GL
            AND
            @All_BBS_Entries = @All_Distinct_MG_AC_GL_Combos
            AND
            @All_Distinct_MG_AC_Combos = @All_Distinct_MG_AC_Combos_With_Default_GL
            AND
            @All_Distinct_MG_AC_Combos_With_Default_GL = @All_Distinct_MG_AC_GL_Combos_With_Default_GL
        THEN ''
        WHEN
            @All_Distinct_MG_AC_Combos > @All_Distinct_MG_AC_Combos_With_Default_GL
            AND
            @All_Distinct_MG_AC_Combos_With_Default_GL = @All_Distinct_MG_AC_GL_Combos_With_Default_GL
        THEN 'MG-AC Combos with no Default GL exist'
        WHEN
            @All_Distinct_MG_AC_Combos = @All_Distinct_MG_AC_Combos_With_Default_GL
            AND
            @All_Distinct_MG_AC_Combos_With_Default_GL < @All_Distinct_MG_AC_GL_Combos_With_Default_GL
        THEN 'MG-AC Combos with >1 Default GL exist'
        WHEN
            @All_Distinct_MG_AC_Combos > @All_Distinct_MG_AC_Combos_With_Default_GL
            AND
            @All_Distinct_MG_AC_Combos_With_Default_GL < @All_Distinct_MG_AC_GL_Combos_With_Default_GL
        THEN 'MG-AC Combos with Both >1 and 0 Default GL exist'
        ELSE 'Unknown error'
    END;
 
SET @Contradiction_In_ReceiveByAmount_Result =
    CASE
        WHEN
            @All_Distinct_MG_AC_Combos = @All_Distinct_MG_AC_Amt_Rec_Combos
        THEN ''
        WHEN
            @All_Distinct_MG_AC_Combos < @All_Distinct_MG_AC_Amt_Rec_Combos
        THEN 'ReceiveByAmount is marked both Yes/No for some MG-AC Combo(s)'
        ELSE 'Unknown error'
    END;
 
END;  -- If @Need_Counts_Check = 'Yes' then this block would execute
--- Finished Declaring and Assigning values to Parameters for performing overall Count based Checks ------
 
WITH Before_CC_CEME_MGGL AS (
 
SELECT
 
----- Baseline Data BBS MG-GL Mapping Entries START -----------------------------------------------------
 
"MG_AC_GL_Map"."MG" AS "MG - Material Group ID",
"MG_AC_GL_Map"."AC" AS "AC - Account Category Name",
CASE
    WHEN "MG_AC_GL_Map"."Preferred" = '1' THEN 'Yes'
    WHEN "MG_AC_GL_Map"."Preferred" = '0' THEN 'No'
    ELSE "MG_AC_GL_Map"."Preferred"
END AS "Preferred AC?",
"MG_AC_GL_Map"."GL" AS "GL - General Ledger ID",
CASE
    WHEN "MG_AC_GL_Map"."Default" = '1' THEN 'Yes'
    WHEN "MG_AC_GL_Map"."Default" = '0' THEN 'No'
    ELSE "MG_AC_GL_Map"."Default"
END AS "Default GL?(Filter 'Yes' for CEME)",
"MG_AC_GL_Map"."Amt_Rec" AS "Amt_Rec - Receive By Amount?",
 
----- Baseline Data BBS MG-GL Mapping Entries END --------------------------------------------------------
 
------------------ MGGL Relation Entry File Portion STARTS-------------------------------------------------
'***RELATION ENTRY STARTS>>>>' AS '***RELATION ENTRY STARTS>>>>',
 
'MaterialGroupToGLMapping' AS "RelationType.UniqueName",
'' AS "RightKey3",
'' AS "LeftKey3",
'' AS "RightKey2",
--"CC"."BUKRS" AS "LeftKey2",
"MG_AC_GL_Map"."MG" AS "RightKey1",
"MG_AC_GL_Map"."GL" AS "LeftKey1",
"MG_AC_GL_Map"."MG" AS "LeftId",
--"MG_AC_GL_Map"."GL"+':'+"CC"."BUKRS" AS "RightId",
 
'<<<<RELATION ENTRY ENDS***' AS '<<<<RELATION ENTRY ENDS***',
------------------ MGGL Relation Entry File Portion ENDS-------------------------------------------------
 
------------------CEME File Portion STARTS---------------------------------------------------------------
'***CEME STARTS(Filter Default GL? as ''Yes'')>>>>' AS '***CEME STARTS(Filter Default GL? as ''Yes'')>>>>',
 
--"CC"."BUKRS" AS "GeneralLedger,CompanyCode",
'M' AS "ItemCategory",
"AT"."UniqueName" AS "AccountType",
'custom' AS "CommonIdDomain",
"MG_AC_GL_Map"."MG" AS "MaterialGroup",
'' AS "CompanyCode1",
'' AS "CurrForMinAndMaxAmt",
'' AS "Asset",
'' AS "DeliverTo",
'' AS "Asset,CompanyCode",
'' AS "CompanyCode2",
'' AS "MinAmt",
'' AS "ShipTo",
'' AS "BillTo",
--"CC"."BUKRS" AS "CompanyCode3",
CASE
    WHEN
        "MG_AC_GL_Map"."Preferred" = '1'
    THEN 'Yes'
    WHEN
        "MG_AC_GL_Map"."Preferred" = '0'
    THEN 'No'
    ELSE "MG_AC_GL_Map"."Preferred"
END AS "Preferred",
--MG_AC_GL_Map.Preferred AS "Preferred",
'' AS "ActivityNumber",
"MG_PG"."PG" AS "SAPPurchaseGroup",
"MG_AC_GL_Map"."GL" AS "GeneralLedger",
'' AS "InternalOrder",
'' AS "Network",
'' AS "MaxAmt",
"MG_GT"."GT_Code" AS "CommonId",
'' AS "WBSElement",
"AC"."KNTTP" AS "AccountCategory",
'' AS "SubAsset",
'' AS "AssetClass",
 
'<<<<CEME ENDS(Filter Default GL? as ''Yes'')***' AS '<<<<CEME ENDS(Filter Default GL? as ''Yes'')***',
------------------CEME File Portion ENDS---------------------------------------------------------------
 
------------------Validation for Data entered by Member Firm Portion STARTS ---------------------------
 
CASE
    WHEN
        "PCC"."UniqueName" IS NOT NULL THEN ''
    ELSE 'Invalid MG'
END AS "01. Valid MG?",
CASE
    WHEN
        "AT"."Name" IS NOT NULL THEN ''
    ELSE 'Invalid Account Assignment'
END AS "02. Valid AccountType?",
CASE
    WHEN
        "MG_AC_GL_Map"."Preferred" IN ('1', '0')
    THEN ''
    ELSE 'Value Other Than Yes/No in "Is Preferred Account Assignment?" column'
END AS "03. Valid MG Preference?",
CASE
    WHEN
        "MG_AC_GL_Map"."Default" IN ('1', '0')
    THEN ''
    ELSE 'Value Other Than Yes/No in "Is Default GL?" column'
END AS "04. Valid GL Defaulting?",
CASE
    WHEN
        "MG_AC_GL_Map"."Amt_Rec" IN ('Yes', 'No')
    THEN ''
    ELSE 'Value Other Than Yes/No in "Requires Receive by Amount to be enabled?" column'
END AS "05. Valid ReceiveByAmount Preference?",
 
CASE
    WHEN
        COUNT(*) OVER (PARTITION BY "MG_AC_GL_Map"."MG", "MG_AC_GL_Map"."AC", "MG_AC_GL_Map"."Preferred", "MG_AC_GL_Map"."GL", "MG_AC_GL_Map"."Default", "MG_AC_GL_Map"."Amt_Rec") > 1
    THEN 'Duplicate Row'
    WHEN
        COUNT(*) OVER (PARTITION BY "MG_AC_GL_Map"."MG", "MG_AC_GL_Map"."AC", "MG_AC_GL_Map"."Preferred", "MG_AC_GL_Map"."GL", "MG_AC_GL_Map"."Default", "MG_AC_GL_Map"."Amt_Rec") = 1
    THEN ''
    ELSE 'Unknown Error'
END AS "06. Duplicate Row(s) exist?",
    --- Condition to check:
    --- If any of the Rows are duplicate entries or not.
 
"Table_To_Check_MG_With_>1_Preferred_Account_Assignment"."Preferred Account Assignmnent>1?" AS "07. Preferred AC >1 for any MG(s)?",
"Table_To_Check_MG_With_No_Preferred_Account_Assignment"."No Preferred Account Assignment?" AS "08. No Preferred AC for any MG(s)?",
"Table_To_Check_MG_With_Contradictory_AC_ReceiveByAmountPreference_DefaultGL<>1"."Account Assignment Contradiction Check" AS "09. Contradicting AC Preference for any MG(s)?",
"Table_To_Check_MG_With_Contradictory_AC_ReceiveByAmountPreference_DefaultGL<>1"."Amount Receiving Contradiction Check" AS "10. Contradicting Amt_Rec Preference for any MG(s)?",
"Table_To_Check_MG_With_Contradictory_AC_ReceiveByAmountPreference_DefaultGL<>1"."Default GL has discrepancy?" AS "11. Default GL<>1 for any MG-AC combo(s)?",
"Table_To_Check_MG_With_Contradictory_AC_ReceiveByAmountPreference_DefaultGL<>1"."Duplicate GL in the MG-AC Combo?" AS "12. Duplicate GL in any MG-AC Combo(s)?",
 
------------------Validation for Data entered by Member Firm Portion ENDS ---------------------------
 
------------------Validation for Internal Data Portion STARTS ------------------------------
 
CASE
    WHEN
        "MG_PG"."MG" IS NOT NULL
    THEN ''
    ELSE 'No Valid PG Mapping'
END AS "13. Valid PG Mapping Present for MG?",
 
CASE
    WHEN
        "MG_GT"."MG" IS NOT NULL
    THEN ''
    ELSE 'No Valid GTCode Mapping'
END AS "14. Valid GTCode Mapping Present for MG?",
 
 
------------------Validation for Internal Data Portion ENDS ---------------------------
 
------------------MDG Related and GAR File Validation Portion STARTS ---------------------------
 
CASE
    WHEN
        ("MG_AC_GL_Map"."GL" = "GAR"."G/L Account From")
        AND
        ("GAR"."G/L Account From" = "GAR"."G/L Account To")
        AND
        ("GAR"."AP entry Allowed" = 'X')
        AND
        ("GAR"."Proj type allwd" IS NOT NULL)
    THEN ''
    WHEN
        ("MG_AC_GL_Map"."GL" = "GAR"."G/L Account From")
        AND
        ("GAR"."G/L Account From" = "GAR"."G/L Account To")
        AND
        ("GAR"."AP entry Allowed" = 'X')
        AND
        ("GAR"."Proj type allwd" IS NULL)
    THEN 'No WBS Types Are Allowed'
    WHEN
        ("MG_AC_GL_Map"."GL" = "GAR"."G/L Account From")
        AND
        ("GAR"."G/L Account From" = "GAR"."G/L Account To")
        AND
        ("GAR"."AP entry Allowed" IS NULL)
        AND
        ("GAR"."Proj type allwd" IS NOT NULL)
    THEN 'AP Entry Not Allowed'
    WHEN
        ("MG_AC_GL_Map"."GL" = "GAR"."G/L Account From")
        AND
        ("GAR"."G/L Account From" = "GAR"."G/L Account To")
        AND
        ("GAR"."AP entry Allowed" IS NULL)
        AND
        ("GAR"."Proj type allwd" IS NULL)
    THEN 'BOTH AP Entry And WBS Types Are Not Allowed'
    WHEN
        (("MG_AC_GL_Map"."GL" = "GAR"."G/L Account From")
        AND
        ("GAR"."G/L Account From" <> "GAR"."G/L Account To"))
        OR
        (("MG_AC_GL_Map"."GL" = "GAR"."G/L Account To")
        AND
        ("GAR"."G/L Account From" <> "GAR"."G/L Account To"))
    THEN 'GL value Mismatch between FROM and TO Columns'
    WHEN
        ("MG_AC_GL_Map"."GL" NOT IN (SELECT "G/L Account From" FROM "ZTRTR_GACC_RULES" WHERE "Member Firm"=@GAR_MemberFirm_ID))
        OR
        ("MG_AC_GL_Map"."GL" NOT IN (SELECT "G/L Account To" FROM "ZTRTR_GACC_RULES" WHERE "Member Firm"=@GAR_MemberFirm_ID))
    THEN 'GL is Not Present in GAR'
    ELSE 'Unknown Error'
END AS "15. Valid GAR-entry?",
 
CASE
    WHEN
        CONCAT("MG_AC_GL_Map"."MG",'-',"MG_AC_GL_Map"."GL") in (SELECT "UniqueName" FROM "MGGLComboExport")
    THEN ''
    ELSE 'Invalid MGGL(FMD)'
END AS "16. Valid MGGL Combo as per MGGL FMD?",
------------------MDG Related and GAR File Validation Portion ENDS ---------------------------
 
-----------------Count Checks START ---------------------------------------
 
'***COUNTS CHECKS START>>>>' AS '***COUNTS CHECKS START>>>>',
 
@All_BBS_Entries AS '01. All BBS Entries',
@All_Distinct_BBS_Entires AS '02. Distinct BBS Entries',
@Duplicates_In_MG_AC_GL_Map_Result AS '03. Duplicates in MG_AC_GL_Map?',
 
@All_Distinct_MGs AS '04. Distinct MGs in BBS',
@All_Distinct_MG_AC_Combos AS '05. Distinct MG-AC Combos in BBS',
 
@All_Distinct_MG_AC_Preferred_Combos AS '06. Distinct MG-AC-Preference Combos in BBS',
@Contradiction_In_AC_Preference_Result AS '07. Contradiction in AC Preference?',
 
@All_Distinct_MG_AC_Amt_Rec_Combos AS '08. Distinct MG-AC-ReceiveByAmount Combos in BBS',
@Contradiction_In_ReceiveByAmount_Result AS '09. Contradiction in ReceiveByAmount Preference?',
 
@All_Distinct_MGs_With_Preferred_AC AS '10. Distinct MGs in BBS having Preferred AC(s)',
@All_Distinct_MG_AC_Combos_With_Preferred_AC AS '11. Distinct MG-AC combo in BBS having Preferred AC(s)',
@MGs_Have_Only_1_Preferred_AC_Or_Not_Result AS '12. Presence of MGs with 0 or >1 Preferred AC(s) or Both',
 
@Contradiction_In_GL_Default_Result AS '13. Contradiction in GL Default?',
@All_Distinct_MGs_With_Preferred_AC_AND_Default_GL AS '14. Distinct MGs in BBS having Preferred AC(s) and Default GL(s)',
@MG_AC_Combos_Have_Only_1_Default_GL_Or_Not_Result AS '15. Presence of MG-AC Combos with 0 or >1 Default GL(s) or Both',
 
'<<<<COUNTS CHECKS END***' AS '<<<<COUNTS CHECKS END***'
-----------------Count Checks END-----------------------------------------
 
FROM 
"MG_AC_GL_Map" AS "MG_AC_GL_Map"
 
LEFT JOIN "MG_PG"
ON "MG_PG"."MG" = "MG_AC_GL_Map"."MG"
--- Added to populate the PURCHASE GROUP ID mapped to the respective MG
 
LEFT JOIN "AccountTypeExport" AS "AT"
ON REPLACE("AT"."Name", ' ','') = REPLACE("MG_AC_GL_Map"."AC", ' ','')
--- Added to populate the ACCOUNT TYPE ID mapped to the Account Type Name (Account Assignment) entered
 
LEFT JOIN "AccountCategoryExport" AS "AC"
ON REPLACE("AC"."KNTTX", ' ','') = REPLACE("MG_AC_GL_Map"."AC", ' ','')
--- Added to populate the ACCOUNT CATEGORY ID mapped to the Account Type Name (Account Assignment) entered
 
LEFT JOIN "PartitionedCommodityCodeExport" AS "PCC"
ON "MG_AC_GL_Map"."MG" = "PCC"."UniqueName"
--- Added to Validate the MG added in BBS MG-GL Sheet
 
LEFT JOIN "ZTRTR_GACC_RULES" AS "GAR"
ON "GAR"."G/L Account From" = "MG_AC_GL_Map"."GL" AND "GAR"."Member Firm" = @GAR_MemberFirm_ID
-- Added to validate the GL against the "S4/SWIFT GAR TABLE". Enter the Menber Firm ID present in the GAR File. For Example for Germany it is "DCE"
 
--LEFT JOIN MG_GT
--ON MG_GT.MG = MG_AC_GL_Map.MG
--- Added to populate the COMMODITY CODE (GLOBAL TAXONOMY CODE) ID mapped to the respective MG.
--- Since there might be more than one matching COMMODITY CODE ID for any given MG, "OUTER APPLY" method is used instead of this simple LEFT JOIN
 
OUTER APPLY (
    SELECT TOP 1
        MG,
        GT_Code
    FROM
        MG_GT
    WHERE
        MG_AC_GL_Map.MG = MG_GT.MG
) MG_GT
--- Added to populate the 1st matching COMMODITY CODE (GLOBAL TAXONOMY CODE) ID mapped to the respective MG
 
LEFT JOIN(
    SELECT
    "MG",
    CASE
        WHEN
            SUM(CONVERT (int, "MG_AC_GL_Map"."Preferred")) = 0
        Then 'No Preferred Account Assignment'
        WHEN
            SUM(CONVERT (int, "MG_AC_GL_Map"."Preferred")) >= 1
        Then ''
        ELSE 'Unknown Error'
    END AS "No Preferred Account Assignment?"
 
    FROM "MG_AC_GL_Map"
    where "MG_AC_GL_Map"."Preferred" in ('1','0')
    GROUP BY "MG" ) AS "Table_To_Check_MG_With_No_Preferred_Account_Assignment"
 
    ON
        "Table_To_Check_MG_With_No_Preferred_Account_Assignment"."MG" = "MG_AC_GL_Map"."MG"
    --- Select Query to check:
    --- if any MG has No Account Assignment chosen as Preferred
    
 
LEFT JOIN (
    SELECT
    MG,
    CASE
        WHEN
            COUNT(DISTINCT AC) > 1
        THEN 'More than one Preferred Account Assignment'
        WHEN
            COUNT(DISTINCT AC) = 1
        THEN ''
        ELSE 'Unknown Error'
    END AS "Preferred Account Assignmnent>1?"
 
    FROM "MG_AC_GL_Map"
    WHERE "Preferred" = '1'
    GROUP BY "MG" ) AS "Table_To_Check_MG_With_>1_Preferred_Account_Assignment"
 
    ON
        "Table_To_Check_MG_With_>1_Preferred_Account_Assignment"."MG" = "MG_AC_GL_Map"."MG"
    --- Select Query to check:
    --- If any MG has more than one Preferred Account Assignment
 
 
LEFT JOIN(
    SELECT
    "MG",
    "AC",
    Count(DISTINCT "Preferred") AS "DISTINCT Preferred AC",
    CASE
        WHEN
            Count(DISTINCT "Preferred") > 1
        THEN 'Contradictory AccountAssignment Preference'
        WHEN
            Count(DISTINCT "Preferred") = 1
        THEN ''
        ELSE 'Unknown Error'
    END AS "Account Assignment Contradiction Check",
    Count(DISTINCT "Amt_Rec") AS "DISTINCT Amt_Rec",
    CASE
        WHEN
            Count(DISTINCT "Amt_Rec") > 1
        THEN 'Contradictory ReceiveByAmount Preference'
        WHEN
            Count(DISTINCT "Amt_Rec") = 1
        THEN ''
        ELSE 'Unknown Error'
    END AS "Amount Receiving Contradiction Check",
    SUM(CONVERT (int, "MG_AC_GL_Map"."Default")) AS "SUM value to check Default GL",
    CASE
        WHEN
            SUM(CONVERT (int, "MG_AC_GL_Map"."Default")) < 1
        Then 'No Default GL Chosen'
        WHEN
            SUM(CONVERT (int, "MG_AC_GL_Map"."Default")) > 1
        Then 'More than 1 Default GL Chosen'
        WHEN
            SUM(CONVERT (int, "MG_AC_GL_Map"."Default")) = 1
        Then ''
        ELSE 'Unknown Error'
    END AS "Default GL has discrepancy?",
    Count(DISTINCT "MG_AC_GL_Map"."GL") AS "Total DISTINCT GLs in the MG-AC",
    Count( "MG_AC_GL_Map"."GL") AS "Total GLs in the MG-AC",
    CASE
        WHEN
            Count(DISTINCT "MG_AC_GL_Map"."GL") = Count( "MG_AC_GL_Map"."GL")
        THEN ''
        WHEN
            Count(DISTINCT "MG_AC_GL_Map"."GL") < Count( "MG_AC_GL_Map"."GL")
        THEN 'Yes-Duplicate GL in the MG-AC Combo'
        ELSE 'Unknown Error'
    END AS "Duplicate GL in the MG-AC Combo?"
 
    FROM "MG_AC_GL_Map"
    where "MG_AC_GL_Map"."Default" in ('1','0')
    GROUP BY "MG", "AC" ) AS "Table_To_Check_MG_With_Contradictory_AC_ReceiveByAmountPreference_DefaultGL<>1"
 
    ON
        "Table_To_Check_MG_With_Contradictory_AC_ReceiveByAmountPreference_DefaultGL<>1"."MG" = "MG_AC_GL_Map"."MG"
        AND
        "Table_To_Check_MG_With_Contradictory_AC_ReceiveByAmountPreference_DefaultGL<>1"."AC" = "MG_AC_GL_Map"."AC"
    --- Select Query to check if:
    --- Any MG has One Account Assignment chosen as both Preferred as well as not-preferred,
    --- One MG-Account Assignment combo is given 'Yes' as well as 'No' for Receive by Amount,
    --- For any MG-AC combo if there's any duplicate GL entered,
    --- And for a particular MG-Account Assignment combo, no. of Default GLs =1 or >1 or <1 i.e. 0
)
 
Select 
 
CONCAT_WS    ('-',
    CASE WHEN "01. Valid MG?" IN ('') THEN '' ELSE '01. Valid MG?' END,
    CASE WHEN "02. Valid AccountType?" IN ('') THEN '' ELSE '02. Valid AccountType?' END,
    CASE WHEN "03. Valid MG Preference?" IN ('') THEN '' ELSE '03. Valid MG Preference?' END,
    CASE WHEN "04. Valid GL Defaulting?" IN ('') THEN '' ELSE '04. Valid GL Defaulting?' END,
    CASE WHEN "05. Valid ReceiveByAmount Preference?" IN ('') THEN '' ELSE '05. Valid ReceiveByAmount Preference' END,
    CASE WHEN "06. Duplicate Row(s) exist?" IN ('') THEN '' ELSE '06. Duplicate Row(s) exist?' END,
    CASE WHEN "07. Preferred AC >1 for any MG(s)?" IN ('') THEN '' ELSE '07. Preferred AC >1 for any MG(s)?' END,
    CASE WHEN "08. No Preferred AC for any MG(s)?" IN ('') THEN '' ELSE '08. No Preferred AC for any MG(s)?' END,
    CASE WHEN "09. Contradicting AC Preference for any MG(s)?" IN ('') THEN '' ELSE '09. Contradicting AC Preference for any MG(s)?' END,
    CASE WHEN "10. Contradicting Amt_Rec Preference for any MG(s)?" IN ('') THEN '' ELSE '10. Contradicting Amt_Rec Preference for any MG(s)?' END,
    CASE WHEN "11. Default GL<>1 for any MG-AC combo(s)?" IN ('') THEN '' ELSE '11. Default GL<>1 for any MG-AC combo(s)?' END,
    CASE WHEN "12. Duplicate GL in any MG-AC Combo(s)?" IN ('') THEN '' ELSE '12. Duplicate GL in any MG-AC Combo(s)?' END,
    CASE WHEN "13. Valid PG Mapping Present for MG?" IN ('') THEN '' ELSE '13. Valid PG Mapping Present for MG?' END,
    CASE WHEN "14. Valid GTCode Mapping Present for MG?" IN ('') THEN '' ELSE '14. Valid GTCode Mapping Present for MG?' END,
    CASE WHEN "15. Valid GAR-entry?" IN ('') THEN '' ELSE '15. Valid GAR-entry?' END,
    CASE WHEN "16. Valid MGGL Combo as per MGGL FMD?" IN ('') THEN '' ELSE '16. Valid MGGL Combo as per MGGL FMD?' END,
    CASE WHEN "GL"."BUKRS" IS NOT NULL THEN ''
         WHEN "GL"."BUKRS" IS NULL THEN '17. Valid CC-GL combo?'
         ELSE '17. Valid CC-GL combo?' END
            ) AS ERROR_Columns,
"CC"."BUKRS" AS "CompanyCode",
"MG - Material Group ID",
"AC - Account Category Name",
"Preferred AC?",
"GL - General Ledger ID",
"Default GL?(Filter 'Yes' for CEME)",
"Amt_Rec - Receive By Amount?",
"***RELATION ENTRY STARTS>>>>",
"RelationType.UniqueName",
"RightKey3",
"LeftKey3",
"RightKey2",
"CC"."BUKRS" AS "LeftKey2",
"RightKey1",
"LeftKey1",
"LeftId",
"GL - General Ledger ID"+':'+"CC"."BUKRS" AS "RightId",
"<<<<RELATION ENTRY ENDS***",
"***CEME STARTS(Filter Default GL? as 'Yes')>>>>",
"CC"."BUKRS" AS "GeneralLedger,CompanyCode",
"ItemCategory",
"AccountType",
"CommonIdDomain",
"MaterialGroup",
"CompanyCode1" AS "CompanyCode",
"CurrForMinAndMaxAmt",
"Asset",
"DeliverTo",
"Asset,CompanyCode",
"CompanyCode2" AS "CompanyCode",
"MinAmt",
"ShipTo",
"BillTo",
"CC"."BUKRS" AS "CompanyCode",
"Preferred",
"ActivityNumber",
"SAPPurchaseGroup",
"GeneralLedger",
"InternalOrder",
"Network",
"MaxAmt",
"CommonId",
"WBSElement",
"AccountCategory",
"SubAsset",
"AssetClass",
"<<<<CEME ENDS(Filter Default GL? as 'Yes')***",
"01. Valid MG?",
"02. Valid AccountType?",
"03. Valid MG Preference?",
"04. Valid GL Defaulting?",
"05. Valid ReceiveByAmount Preference?",
"06. Duplicate Row(s) exist?",
"07. Preferred AC >1 for any MG(s)?",
"08. No Preferred AC for any MG(s)?",
"09. Contradicting AC Preference for any MG(s)?",
"10. Contradicting Amt_Rec Preference for any MG(s)?",
"11. Default GL<>1 for any MG-AC combo(s)?",
"12. Duplicate GL in any MG-AC Combo(s)?",
"13. Valid PG Mapping Present for MG?",
"14. Valid GTCode Mapping Present for MG?",
"15. Valid GAR-entry?",
"16. Valid MGGL Combo as per MGGL FMD?",
"GL"."BUKRS" AS "CC ID from GL Export",
"GL"."SAKNR" AS "GL ID from GL Export",
CASE
    WHEN "GL"."BUKRS" IS NOT NULL THEN ''
    WHEN "GL"."BUKRS" IS NULL THEN 'Invalid CC-GL'
    ELSE 'Unknown Error'
END AS "17. Valid CC-GL combo?",
"***COUNTS CHECKS START>>>>",
"01. All BBS Entries",
"02. Distinct BBS Entries",
"03. Duplicates in MG_AC_GL_Map?",
"04. Distinct MGs in BBS",
"05. Distinct MG-AC Combos in BBS",
"06. Distinct MG-AC-Preference Combos in BBS",
"07. Contradiction in AC Preference?",
"08. Distinct MG-AC-ReceiveByAmount Combos in BBS",
"09. Contradiction in ReceiveByAmount Preference?",
"10. Distinct MGs in BBS having Preferred AC(s)",
"11. Distinct MG-AC combo in BBS having Preferred AC(s)",
"12. Presence of MGs with 0 or >1 Preferred AC(s) or Both",
"13. Contradiction in GL Default?",
"14. Distinct MGs in BBS having Preferred AC(s) and Default GL(s)",
"15. Presence of MG-AC Combos with 0 or >1 Default GL(s) or Both",
"<<<<COUNTS CHECKS END***"
 
from Before_CC_CEME_MGGL
CROSS JOIN "CompanyCodeExport" AS "CC"
--Added to generate the "CARTESIAN PRODUCT" of Company Code and MGGL Lists
 
LEFT JOIN GeneralLedgerExport AS "GL"
ON "GL"."BUKRS" = "CC".BUKRS AND "GL"."SAKNR" = "GL - General Ledger ID"
 
WHERE "CC".BUKRS IN (SELECT BUKRS FROM #Temp_CompanyCode_List)
 
/* 
WHERE
    CASE
        WHEN
            @CompanyCode_Column_BUKRS_Or_FSTVA = 'BUKRS'
        THEN "CC"."BUKRS"
        WHEN
            @CompanyCode_Column_BUKRS_Or_FSTVA = 'FSTVA'
        THEN "CC"."FSTVA"
        ELSE NULL
    END IN (@CompanyCode_Value_IDs_Or_Variants)     --- enter the Company code filter for which CEME, MGGL Relation entry files needs to be created.
--AND "MG_AC_GL_Map"."MG" in ('M179')
*/
 
ORDER BY
"CC"."BUKRS",
"MG - Material Group ID",
"Preferred AC?" DESC,
"AC - Account Category Name",
"Default GL?(Filter 'Yes' for CEME)" DESC,
"GL - General Ledger ID";
 
UPDATE "MG_AC_GL_Map" SET "Preferred" = 'Yes' WHERE "Preferred" = '1';
UPDATE "MG_AC_GL_Map" SET "Preferred" = 'No' WHERE "Preferred" = '0';
UPDATE "MG_AC_GL_Map" SET "Default" = 'Yes' WHERE "Default" = '1';
UPDATE "MG_AC_GL_Map" SET "Default" = 'No' WHERE "Default" = '0';
 
END;
GO

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
