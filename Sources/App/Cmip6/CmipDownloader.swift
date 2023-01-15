import Foundation
import Vapor
import SwiftPFor2D
import SwiftNetCDF


/**
 https://esgf-data.dkrz.de/search/cmip6-dkrz/
 https://esgf-node.llnl.gov/search/cmip6/
 
 INTERESSTING:
 
 CMCC-CM2-VHR4 (CMCC Italy) https://www.wdc-climate.de/ui/cmip6?input=CMIP6.HighResMIP.CMCC.CMCC-CM2-VHR4
 0.3125°
 6h: 2m temp, humidity, wind, surface temp,
 daily: 2m temp, humidity. wind, precip, longwave,
 monthly: temp, clouds, precip, runoff, wind, soil moist 1 level, humidity, snow,
 NO daily min/max directly
 
 FGOALS-f3  (CAS China) https://www.wdc-climate.de/ui/cmip6?input=CMIP6.HighResMIP.CAS.FGOALS-f3-H.highresSST-future
 0.25°
 3h: air tmp, clc, wind, hum, sw
 6h: missing temperature for higher altitude,
 day: missing temperature for land,clc, wind, hum, precip, sw,
 monthly: temp, clc, wind, hum, precip,
 NO daily min/max directly
 
 HiRAM-SIT-HR (RCEC taiwan) https://www.wdc-climate.de/ui/cmip6?input=CMIP6.HighResMIP.AS-RCEC.HiRAM-SIT-HR
 0.23°
 daily: 2m temp, surface temp (min max), clc, precip, wind, snow, swrad
 monthly: 2m temp, clc, wind, hum, snow, swrad,
 
 MRI-AGCM3-2-S (MRI Japan, ) https://www.wdc-climate.de/ui/cmip6?input=CMIP6.HighResMIP.MRI.MRI-AGCM3-2-S.highresSST-present
 0.1875°
 3h: 2m temp, wind, soil moisture, hum, surface temperature
 day: temp, clc, soild moist, wind, hum, runoff, precip, snow, swrad,
 month: same
 
 MEDIUM:
 
 NICAM16-9S https://gmd.copernicus.org/articles/14/795/2021/
 0.14°, but only 2040-2050 and 1950–1960, 2000–2010 (high computational cost hindered us from running NICAM16-9S for 100 years)
 1h: precip
 3h: precip, clc, snow, swrad (+cs), temp, wind, pres, hum
 day: temp, clc, wind, precip, snow, hum, swrad,
 month: temp, (clc), precio, runoff,
 
 LESS:
 
 CESM1-CAM5-SE-HR -> old model from 2012
 native ne120 spectral element grid... 25km
 day: only ocean
 monthly: NO 2m temp, surface (min,max), clc, wind, hum, snow, swrad,
 
 HiRAM-SIT-LR: only present
 
 ACCESS-OM2-025: only ocean
 AWI-CM-1-1-HR: only ocean
 
 ECMWF-IFS-HR: only present, not forecast
 0.5°
 6h: 2m temp, wind, hum, pres
 day: 2m temp, clouds, precip, wind, hum, snow, swrad, surface temp (min/max),
 month: temp 2m, clc, wind, leaf area index, precip, runoff, soil moist, soil temp, hum,
 
 IPSL-CM6A-ATM-ICO-VHR: ipsl france: only 1950-2014
 
 MRI-AGCM3-2-H
 0.5°
 6h: pres, 2m temp, wind, hum
 day: 2m temp, clc, wind, soil moist, precip, runoff, snow, hum, swrad, (T pressure levels = only 1000hpa.. massive holes!)
 mon: 2m temp, surface temp, clc, wind, hum, swrad,
 
 
 Sizes:
 MRI: Raw 2.15TB, Compressed 413 GB
 HiRAM_SIT_HR_daily: Raw 1.3TB, Compressed 210 GB
 FGLOALS: Raw 1.2 TB, Compressed 120 GB
 */

enum Cmip6Domain: String, Codable, GenericDomain {
    case CMCC_CM2_VHR4
    case FGOALS_f3_H
    case HiRAM_SIT_HR
    case MRI_AGCM3_2_S
    
    /// https://gmd.copernicus.org/articles/12/4999/2019/gmd-12-4999-2019.pdf
    case HadGEM3_GC31_HM
    
    var soureName: String {
        switch self {
        case .CMCC_CM2_VHR4:
            return "CMCC-CM2-VHR4"
        case .FGOALS_f3_H:
            return "FGOALS-f3-H"
        case .HiRAM_SIT_HR:
            return "HiRAM-SIT-HR"
        case .MRI_AGCM3_2_S:
            return "MRI-AGCM3-2-S"
        case .HadGEM3_GC31_HM:
            return "HadGEM3-GC31-HM"
        }
    }
    
    var gridName: String {
        switch self {
        case .CMCC_CM2_VHR4:
            return "gn"
        case .FGOALS_f3_H:
            return "gr"
        case .HiRAM_SIT_HR:
            return "gn"
        case .MRI_AGCM3_2_S:
            return "gn"
        case .HadGEM3_GC31_HM:
            return "gn"
        }
    }
    
    var institute: String {
        switch self {
        case .CMCC_CM2_VHR4:
            return "CMCC"
        case .FGOALS_f3_H:
            return "CAS"
        case .HiRAM_SIT_HR:
            return "AS-RCEC"
        case .MRI_AGCM3_2_S:
            return "MRI"
        case .HadGEM3_GC31_HM:
            return "MOHC"
        }
    }
    
    var omfileDirectory: String {
        return "\(OpenMeteo.dataDictionary)omfile-\(rawValue)/"
    }
    var downloadDirectory: String {
        return "\(OpenMeteo.dataDictionary)download-\(rawValue)/"
    }
    var omfileArchive: String? {
        return "\(OpenMeteo.dataDictionary)archive-\(rawValue)/"
    }
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    var dtSeconds: Int {
        return 24*3600
    }
    
    private static var elevationCMCC_CM2_VHR4 = try? OmFileReader(file: Self.CMCC_CM2_VHR4.surfaceElevationFileOm)
    private static var elevationFGOALS_f3_H = try? OmFileReader(file: Self.FGOALS_f3_H.surfaceElevationFileOm)
    private static var elevationHiRAM_SIT_HR = try? OmFileReader(file: Self.HiRAM_SIT_HR.surfaceElevationFileOm)
    private static var elevationMRI_AGCM3_2_S = try? OmFileReader(file: Self.MRI_AGCM3_2_S.surfaceElevationFileOm)
    private static var elevationHadGEM3_GC31_HM = try? OmFileReader(file: Self.HadGEM3_GC31_HM.surfaceElevationFileOm)
    
    var elevationFile: OmFileReader<MmapFile>? {
        switch self {
        case .CMCC_CM2_VHR4:
            return Self.elevationCMCC_CM2_VHR4
        case .FGOALS_f3_H:
            return Self.elevationFGOALS_f3_H
        case .HiRAM_SIT_HR:
            return Self.elevationHiRAM_SIT_HR
        case .MRI_AGCM3_2_S:
            return Self.elevationMRI_AGCM3_2_S
        case .HadGEM3_GC31_HM:
            return Self.elevationHadGEM3_GC31_HM
        }
    }
    
    var omFileLength: Int {
        // has no realtime updates -> large number takes only 1 file lookup
        return 1000000000000000
    }
    
    var grid: Gridable {
        switch self {
        case .CMCC_CM2_VHR4:
            return RegularGrid(nx: 1152, ny: 768, latMin: -90, lonMin: -180, dx: 0.3125, dy: 180/768)
        case .FGOALS_f3_H:
            return RegularGrid(nx: 1440, ny: 720, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
        case .HiRAM_SIT_HR:
            return RegularGrid(nx: 1536, ny: 768, latMin: -90, lonMin: -180, dx: 360/1536, dy: 180/768)
        case .MRI_AGCM3_2_S:
            return RegularGrid(nx: 1920, ny: 960, latMin: -90, lonMin: -180, dx: 0.1875, dy: 0.1875)
        case .HadGEM3_GC31_HM:
            return RegularGrid(nx: 1024, ny: 768, latMin: -90, lonMin: -180, dx: 360/1024, dy: 180/768)
        }
    }
    
    var versionOrography: (altitude: String, landmask: String)? {
        switch self {
        case .CMCC_CM2_VHR4:
            return ("20210330", "20210330")
        case .FGOALS_f3_H:
            return ("20201204", "20210121")
        case .HiRAM_SIT_HR:
            return nil
        case .MRI_AGCM3_2_S:
            return ("20200305", "20200305")
        case .HadGEM3_GC31_HM:
            return ("20200910", "20200910")
        }
    }
}

enum Cmip6Variable: String, CaseIterable, GenericVariable, Codable, GenericVariableMixable {
    case pressure_msl
    case temperature_2m_min
    case temperature_2m_max
    case temperature_2m_mean
    case cloudcover_mean
    case precipitation_sum
    // Note: runoff includes soil drainage -> not surface runoff
    //case runoff_sum
    case snowfall_water_equivalent_sum
    case relative_humidity_2m_min
    case relative_humidity_2m_max
    case relative_humidity_2m_mean
    case windspeed_10m_mean
    case windspeed_10m_max
    
    //case surface_temperature
    
    /// Moisture in Upper Portion of Soil Column.
    case soil_moisture_0_to_10cm
    case shortwave_radiation_sum
    
    enum TimeType {
        case monthly
        case yearly
        case tenYearly
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var omFileName: String {
        return rawValue
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .temperature_2m_min:
            return .hermite(bounds: nil)
        case .temperature_2m_max:
            return .hermite(bounds: nil)
        case .temperature_2m_mean:
            return .hermite(bounds: nil)
        case .cloudcover_mean:
            return .linear
        case .precipitation_sum:
            return .backwards_sum
        //case .runoff_sum:
        //    return .backwards_sum
        case .snowfall_water_equivalent_sum:
            return .backwards_sum
        case .relative_humidity_2m_min:
            return .hermite(bounds: 0...100)
        case .relative_humidity_2m_max:
            return .hermite(bounds: 0...100)
        case .relative_humidity_2m_mean:
            return .hermite(bounds: 0...100)
        case .windspeed_10m_mean:
            return .hermite(bounds: nil)
        case .windspeed_10m_max:
            return .hermite(bounds: nil)
        case .soil_moisture_0_to_10cm:
            return .hermite(bounds: nil)
        case .shortwave_radiation_sum:
            return .hermite(bounds: 0...1800*24)
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .pressure_msl:
            return .hectoPascal
        case .temperature_2m_min:
            return .celsius
        case .temperature_2m_max:
            return .celsius
        case .temperature_2m_mean:
            return .celsius
        case .cloudcover_mean:
            return .percent
        case .precipitation_sum:
            return .millimeter
        //case .runoff_sum:
        //    return .millimeter
        case .snowfall_water_equivalent_sum:
            return .millimeter
        case .relative_humidity_2m_min:
            return .percent
        case .relative_humidity_2m_max:
            return .percent
        case .relative_humidity_2m_mean:
            return .percent
        case .windspeed_10m_mean:
            return .ms
        case .windspeed_10m_max:
            return .ms
        case .soil_moisture_0_to_10cm:
            return .gramPerKilogram
        case .shortwave_radiation_sum:
            return .megaJoulesPerSquareMeter
        }
    }
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m_max || self == .temperature_2m_min || self == .temperature_2m_mean
    }
    
    
    func version(for domain: Cmip6Domain, isFuture: Bool) -> String {
        switch domain {
        case .CMCC_CM2_VHR4:
            if self == .precipitation_sum {
                return "20210308"
            }
            return isFuture ? "20190725" : "20170927"
        case .FGOALS_f3_H:
            return "20190817"
        case .HiRAM_SIT_HR:
            if isFuture {
                return "20210707"
            }
            return "20210713" // "20210707"
        case .MRI_AGCM3_2_S:
            if isFuture {
                return "20200619"
            }
            return "20190711"
        case .HadGEM3_GC31_HM:
            return isFuture ? "20190315" : "20170831"
        }
    }
    
    var scalefactor: Float {
        switch self {
        case .pressure_msl:
            return 10
        case .temperature_2m_min:
            return 20
        case .temperature_2m_max:
            return 20
        case .temperature_2m_mean:
            return 20
        case .cloudcover_mean:
            return 1
        case .precipitation_sum:
            return 10
        //case .runoff_sum:
        //    return 10
        case .snowfall_water_equivalent_sum:
            return 10
        case .relative_humidity_2m_min:
            return 1
        case .relative_humidity_2m_max:
            return 1
        case .relative_humidity_2m_mean:
            return 1
        case .windspeed_10m_mean:
            return 10
        case .windspeed_10m_max:
            return 10
        //case .surface_temperature:
        //    return 20
        case .soil_moisture_0_to_10cm:
            return 1000
        case .shortwave_radiation_sum:
            return 10
        }
    }
    
    func domainTimeRange(for domain: Cmip6Domain) -> TimeType? {
        switch domain {
        case .MRI_AGCM3_2_S:
            switch self {
            case .pressure_msl:
                return .yearly
            case .temperature_2m_min:
                return .yearly
            case .temperature_2m_max:
                return .yearly
            case .temperature_2m_mean:
                return .yearly
            case .cloudcover_mean:
                return .yearly
            case .precipitation_sum:
                return .yearly
            //case .runoff_sum:
            //    return .yearly
            case .snowfall_water_equivalent_sum:
                return .yearly
            case .relative_humidity_2m_min:
                return .yearly
            case .relative_humidity_2m_max:
                return .yearly
            case .relative_humidity_2m_mean:
                return .yearly
            //case .surface_temperature:
            //    return .yearly
            case .soil_moisture_0_to_10cm:
                return .yearly
            case .shortwave_radiation_sum:
                return .yearly
            case.windspeed_10m_max:
                return .yearly
            case .windspeed_10m_mean:
                return .yearly
            }
        case .HadGEM3_GC31_HM:
            // Has all
            return .yearly
        case .CMCC_CM2_VHR4:
            // no near surface RH, only specific humidity
            // also no near surface temp, only 1000 hPa temp
            // temp, rh, pressure can only be calcuated with 6h values
            switch self {
            //case .relative_humidity_2m:
            //    return .monthly
            case .precipitation_sum:
                // only precip is in yearly files...
                return .yearly
            //case .temperature_2m:
            //    return .monthly
            case .windspeed_10m_mean:
                return .monthly
            case .windspeed_10m_max:
                return .monthly
            default:
                return nil
            }
        case .FGOALS_f3_H:
            // no near surface RH, only specific humidity
            // temp min/max and rh/min max can only be calculated form 3h values
            switch self {
            case .relative_humidity_2m_mean:
                return .yearly
            case .cloudcover_mean:
                return .yearly
            case .temperature_2m_mean:
                return .yearly
            case .pressure_msl:
                return .yearly
            case .snowfall_water_equivalent_sum:
                return .yearly
            case .shortwave_radiation_sum:
                return .yearly
            case .windspeed_10m_mean:
                return .yearly
            case .windspeed_10m_max:
                return .yearly
            case .precipitation_sum:
                return .yearly
            default:
                return nil
            }
        case .HiRAM_SIT_HR:
            // no u/v wind components near surface
            // rh daily min/max impossible to get get
            // no wind daily max possible
            switch self {
            case .temperature_2m_mean:
                return .yearly
            case .temperature_2m_max:
                return .yearly
            case .temperature_2m_min:
                return .yearly
            case .cloudcover_mean:
                return .yearly
            case .precipitation_sum:
                return .yearly
            case .snowfall_water_equivalent_sum:
                return .yearly
            case .relative_humidity_2m_mean:
                return .yearly
            case .shortwave_radiation_sum:
                return .yearly
            case .windspeed_10m_mean:
                return .yearly
            default:
                return nil
            }
        }
    }
    
    /// hourly the same but no min/max. Hourly one file per month. Daily = yearly file
    var shortname: String {
        switch self {
        case .pressure_msl:
            return "psl"
        case .temperature_2m_min:
            return "tasmin"
        case .temperature_2m_max:
            return "tasmax"
        case .temperature_2m_mean:
            return "tas"
        case .cloudcover_mean:
            return "clt"
        case .precipitation_sum:
            return "pr"
        case .relative_humidity_2m_min:
            return "hursmin"
        case .relative_humidity_2m_max:
            return "hursmax"
        case .relative_humidity_2m_mean:
            return "hurs"
        //case .runoff_sum:
        //    return "mrro"
        case .snowfall_water_equivalent_sum:
            return "prsn" //kg m-2 s-1
        case .soil_moisture_0_to_10cm: // Moisture in Upper Portion of Soil Column
            return "mrsos"
        case .shortwave_radiation_sum:
            return "rsds"
        //case .surface_temperature:
        //    return "tslsi"
        case .windspeed_10m_mean:
            return "sfcWind"
        case .windspeed_10m_max:
            return "sfcWindmax"
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m_min:
            fallthrough
        case .temperature_2m_max:
            fallthrough
        case .temperature_2m_mean:
            return (1, -273.15)
        case .pressure_msl:
            return (1/100, 0)
        case .precipitation_sum:
            fallthrough
        case .snowfall_water_equivalent_sum:
            return (3600*24, 0)
        //case .runoff_sum:
        //    return (3600*24, 0)
        case .shortwave_radiation_sum:
            return (24*0.0036, 0) // mean w/m2 to MJ/m2 sum
        default:
            return nil
        }
    }
}

struct DownloadCmipCommand: AsyncCommandFix {
    /// 6k locations require around 200 MB memory for a yearly time-series
    static var nLocationsPerChunk = 6_000
    
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String
    }
    
    var help: String {
        "Download CMIP6 data and convert"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        let deleteNetCDF = true
        let years = 1950...2050 // [1950, 2014]
        
        guard let domain = Cmip6Domain.init(rawValue: signature.domain) else {
            fatalError("Invalid domain '\(signature.domain)'")
        }
        
        // Automatically try all servers. From fastest to slowest
        let servers = ["https://esgf3.dkrz.de/thredds/fileServer/cmip6/",
                       "https://esgf.ceda.ac.uk/thredds/fileServer/esg_cmip6/CMIP6/",
                       "https://esgf-data1.llnl.gov/thredds/fileServer/css03_data/CMIP6/",
                       "https://esgf-data04.diasjp.net/thredds/fileServer/esg_dataroot/CMIP6/",
                       "https://esgf-data03.diasjp.net/thredds/fileServer/esg_dataroot/CMIP6/",
                       "https://esg.lasg.ac.cn/thredds/fileServer/esg_dataroot/CMIP6/"]
        
        guard let yearlyPath = domain.omfileArchive else {
            fatalError("yearly archive path not defined")
        }
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: yearlyPath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        let curl = Curl(logger: logger, client: context.application.dedicatedHttpClient, readTimeout: 3600*3, retryError4xx: false)
        let source = domain.soureName
        let grid = domain.gridName
        
        /// Make sure elevation information is present. Otherwise download it
        if let version = domain.versionOrography, !FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm) {
            let ncFileAltitude = "\(domain.downloadDirectory)orog_fx.nc"
            let experimentId = domain == .HadGEM3_GC31_HM ? "hist-1950" : "highresSST-present"
            if !FileManager.default.fileExists(atPath: ncFileAltitude) {
                let uri = "HighResMIP/\(domain.institute)/\(source)/\(experimentId)/r1i1p1f1/fx/orog/\(grid)/v\(version.altitude)/orog_fx_\(source)_\(experimentId)_r1i1p1f1_\(grid).nc"
                try await curl.download(servers: servers, uri: uri, toFile: ncFileAltitude)
            }
            let ncFileLandFraction = "\(domain.downloadDirectory)sftlf_fx.nc"
            if !FileManager.default.fileExists(atPath: ncFileLandFraction) {
                let uri = "HighResMIP/\(domain.institute)/\(source)/\(experimentId)/r1i1p1f1/fx/sftlf/\(grid)/v\(version.landmask)/sftlf_fx_\(source)_\(experimentId)_r1i1p1f1_\(grid).nc"
                try await curl.download(servers: servers, uri: uri, toFile: ncFileLandFraction)
            }
            var altitude = try NetCDF.read(path: ncFileAltitude, short: "orog", fma: nil)
            let landFraction = try NetCDF.read(path: ncFileLandFraction, short: "sftlf", fma: nil)
            
            for i in altitude.data.indices {
                if landFraction.data[i] < 0.5 {
                    altitude.data[i] = -999
                }
            }
            //try altitude.transpose().writeNetcdf(filename: "\(domain.downloadDirectory)elevation.nc", nx: domain.grid.nx, ny: domain.grid.ny)
            try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: domain.surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, all: altitude.data)
            
            if deleteNetCDF {
                try FileManager.default.removeItem(atPath: ncFileAltitude)
                try FileManager.default.removeItem(atPath: ncFileLandFraction)
            }
        }
        
        for variable in Cmip6Variable.allCases { // [Cmip6Variable.precipitation_sum] { //
            guard let timeType = variable.domainTimeRange(for: domain) else {
                continue
            }
            
            for year in years {
                logger.info("Downloading \(variable) for year \(year)")
                let version = variable.version(for: domain, isFuture: year >= 2015)
                let experimentId = year >= 2015 ? "highresSST-future" : "highresSST-present"
                
                switch timeType {
                case .monthly:
                    let omFile = "\(yearlyPath)\(variable.rawValue)_\(year).om"
                    if FileManager.default.fileExists(atPath: omFile) {
                        continue
                    }
                    
                    // download month files and combine to yearly file
                    let short = variable.shortname
                    for month in 1...12 {
                        let ncFile = "\(domain.downloadDirectory)\(short)_\(year)\(month).nc"
                        let monthlyOmFile = "\(domain.downloadDirectory)\(short)_\(year)\(month).om"
                        if !FileManager.default.fileExists(atPath: monthlyOmFile) {
                            // Feb 29 is ignored.....
                            let day = month == 2 ? 28 : YearMonth(year: year, month: month).advanced(by: 1).timestamp.add(hours: -1).toComponents().day
                            let uri = "HighResMIP/\(domain.institute)/\(source)/\(experimentId)/r1i1p1f1/day/\(short)/\(grid)/v\(version)/\(short)_day_\(source)_\(experimentId)_r1i1p1f1_\(grid)_\(year)\(month.zeroPadded(len: 2))01-\(year)\(month.zeroPadded(len: 2))\(day).nc"
                            try await curl.download(servers: servers, uri: uri, toFile: ncFile)
                            
                            // TODO: support for specific humdity to relative humidity if required
                            
                            let array = try NetCDF.read(path: ncFile, short: short, fma: variable.multiplyAdd)
                            try FileManager.default.removeItem(atPath: ncFile)
                            try OmFileWriter(dim0: array.nLocations, dim1: array.nTime, chunk0: Self.nLocationsPerChunk, chunk1: array.nTime).write(file: monthlyOmFile, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: array.data)
                        }
                    }
                    
                    let progress = ProgressTracker(logger: logger, total: domain.grid.count, label: "Convert \(variable.rawValue)")

                    let monthlyReader = try (1...12).map { month in
                        let monthlyOmFile = "\(domain.downloadDirectory)\(short)_\(year)\(month).om"
                        return try OmFileReader(file: monthlyOmFile)
                    }
                    let nt = TimerangeDt(start: Timestamp(year,1,1), to: Timestamp(year+1,1,1), dtSeconds: domain.dtSeconds).count

                    try OmFileWriter(dim0: domain.grid.count, dim1: nt, chunk0: 6, chunk1: 183).write(file: omFile, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, supplyChunk: { dim0 in
                        /// Process around 200 MB memory at once
                        let locationRange = dim0..<min(dim0+Self.nLocationsPerChunk, domain.grid.count)

                        var fasttime = Array2DFastTime(data: [Float](repeating: .nan, count: nt * locationRange.count), nLocations: locationRange.count, nTime: nt)

                        var timeOffest = 0
                        for omfile in monthlyReader {
                            try omfile.willNeed(dim0Slow: locationRange, dim1: 0..<omfile.dim1)
                            let read = try omfile.read(dim0Slow: locationRange, dim1: 0..<omfile.dim1)
                            let read2d = Array2DFastTime(data: read, nLocations: locationRange.count, nTime: omfile.dim1)
                            for l in 0..<locationRange.count {
                                fasttime[l, timeOffest ..< timeOffest + omfile.dim1] = read2d[l, 0..<omfile.dim1]
                            }
                            timeOffest += omfile.dim1
                        }
                        progress.add(locationRange.count)
                        return ArraySlice(fasttime.data)
                    })
                    progress.finish()
                    
                    if deleteNetCDF {
                        for month in 1...12 {
                            try FileManager.default.removeItem(atPath: "\(domain.downloadDirectory)\(short)_\(year)\(month).om")
                        }
                    }

                    //try Array2DFastTime(data: try OmFileReader(file: omFile).readAll(), nLocations: domain.grid.count, nTime: nt).transpose().writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.shortname)_\(year)_converted.nc", nx: domain.grid.nx, ny: domain.grid.ny)
                case .yearly:
                    let omFile = "\(yearlyPath)\(variable.rawValue)_\(year).om"
                    if FileManager.default.fileExists(atPath: omFile) {
                        continue
                    }
                    /// `FGOALS_f3_H` has no near surface relative humidity, calculate from specific humidity
                    let calculateRhFromSpecificHumidity = domain == .FGOALS_f3_H && variable == .relative_humidity_2m_mean
                    let short = calculateRhFromSpecificHumidity ? "huss" : variable.shortname
                    let ncFile = "\(domain.downloadDirectory)\(short)_\(year).nc"
                    if !FileManager.default.fileExists(atPath: ncFile) {
                        /// MetOffice is using 30th december....
                        let lastday = domain == .HadGEM3_GC31_HM ? "1230" : "1231"
                        let uri = "HighResMIP/\(domain.institute)/\(source)/\(experimentId)/r1i1p1f1/day/\(short)/\(grid)/v\(version)/\(short)_day_\(source)_\(experimentId)_r1i1p1f1_\(grid)_\(year)0101-\(year)\(lastday).nc"
                        try await curl.download(servers: servers, uri: uri, toFile: ncFile)
                    }
                    var array = try NetCDF.read(path: ncFile, short: short, fma: variable.multiplyAdd)
                    if calculateRhFromSpecificHumidity {
                        let pressure = try NetCDF.read(path: "\(domain.downloadDirectory)psl_\(year).nc", short: "psl", fma: (1/100, 0))
                        let elevation = try domain.elevationFile!.readAll()
                        let temp = try NetCDF.read(path: "\(domain.downloadDirectory)tas_\(year).nc", short: "tas", fma: (1, -273.15))
                        array.data.multiplyAdd(multiply: 1000, add: 0)
                        array.data = Meteorology.specificToRelativeHumidity(specificHumidity: array, temperature: temp, sealLevelPressure: pressure, elevation: elevation)
                        //try array.transpose().writeNetcdf(filename: "\(domain.downloadDirectory)rh.nc", nx: domain.grid.nx, ny: domain.grid.ny)
                    }
                    //try array.transpose().writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.rawValue)_\(year).nc", nx: domain.grid.nx, ny: domain.grid.ny)
                    try OmFileWriter(dim0: array.nLocations, dim1: array.nTime, chunk0: 6, chunk1: 183).write(file: omFile, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: array.data)
                    if deleteNetCDF {
                        try FileManager.default.removeItem(atPath: ncFile)
                    }
                case .tenYearly:
                    fatalError("ten yearly")
                }
            }
        }
    }
}

extension NetCDF {
    fileprivate static func read(path: String, short: String, fma: (multiply: Float, add: Float)?) throws -> Array2DFastTime {
        guard let ncFile = try NetCDF.open(path: path, allowUpdate: false) else {
            fatalError("Could not open nc file for \(short)")
        }
        guard let ncVar = ncFile.getVariable(name: short) else {
            fatalError("Could not open nc variable for \(short)")
        }
        guard let ncFloat = ncVar.asType(Float.self) else {
            fatalError("Not a float nc variable")
        }
        /// 3d spatial oriented file
        let dim = ncVar.dimensionsFlat
        let nt = dim.count == 3 ? dim[0] : 1
        let nx = dim[dim.count-1]
        let ny = dim[dim.count-2]
        /// transpose to fast time
        var spatial = Array2DFastSpace(data: try ncFloat.read(), nLocations: nx*ny, nTime: nt)
        spatial.data.shift180Longitude(nt: nt, ny: ny, nx: nx)
        if let fma {
            spatial.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
        }
        //try spatial.writeNetcdf(filename: "\(path)4", nx: dim[2], ny: dim[1])
        return spatial.transpose()
    }
}

extension Curl {
    /// Retry download from multiple servers
    /// NOTE: retry 404 should be disabled!
    fileprivate func download(servers: [String], uri: String, toFile: String) async throws {
        for (i,server) in servers.enumerated() {
            do {
                let url = "\(server)\(uri)"
                try await download(url: url, toFile: toFile, bzip2Decode: false)
                break
            } catch CurlError.downloadFailed(let code) {
                if code == .notFound && i != servers.count-1 {
                    continue
                }
                throw CurlError.downloadFailed(code: code)
            }
        }
    }
}