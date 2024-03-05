//
//  FixtureData.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/5/24.
//

import Foundation

struct FixtureData {
  static var places: [Place] = {
    let response: AutocompleteResponse = load("autocomplete.json")
    let places = response.places
    return places
  }()

  static var trips: [Trip] = {
    let encodedGeometry =
      "wpxvyA~w~ihFxIDAhDEnQCnA]nC_BdJ]Va@hASvCorD_@k~DnAkNDoxFAke@a@iKq@cG}AuEaCqG}EwMcQiI{K_CmDcAkAqNgPoYcVqIeFaGiD}IaEwcAi_@yLuDaIeCcD_AeYaIyKa@aEMyOmDmSyH}t@u[cEiCuFkFkDmDuAyAaSoJcNuD}OcAwVMoU?klBCmEUeDqA_C}Bg@{AAuDqHg@aAG_Uf@_YhBqMx@_I`@cM`@oAAiJCiIVgCDqYf@oJJeFP}FFwYPaKTgDDuCByGIyJQeNGeE\\_@DmD`@gCp@cATaB^mDfA_DfAwD`B_MnHcJYmCbB}BtAq_@zYyFrFyBlBw_@~\\cFnEsBsG{Mmb@eBmFcBqFqF}PkAoDaBcFmHyToBaG_CtByJvIoUjS}CnCmC~Bid@z`@{ApAaBxAud@da@YTaBvAwChCwc@j`@iB`BkCbCsDjDeUxR{X|UcCrBqC`Cyg@zc@qIpHOLyEfEoC~B{CnCkPxNaGbFyU~RwCbCcCvBmSrQuCfCwB{CeCoDoKgOEIeMsQoDcFmBmCsAoBwNqSwAoBsK_OcDqEwD{EgAkBiJqL{F}H{GsJwB_DwAsBmCyDaOwSkNeS}@oA}CuE{@oAqHoKcE}FuEf@iEd@yTrB{BRqBRwGf@oE`@kKfAuANqMzAeCXkD`@gUrC_BRcCZc@x@{@dB_CtE{@dBiTtb@oBxDkCjF_HfNaJvQiSja@iBrDwBhEkh@vdA{AzC_AnBg@bAiYll@iAzBuAlB_BxAeBdAkBn@oBXoBBcA?mMCeEAcDAeQGqQGmIEqFAwFE_E?wCCuWIme@KsCAyDA{b@EsIA{@?yDAsFA{DA}C?}NBwO?g\\?yC@wDAiL@sF?aUByD?Y?eH@sCAqD?}FDiC?kA?oOQ_CAaCAeGAuEA_BAmD?wCCyi@YgDCuEA{XImQGsCAqCA_H?sAAaj@Iwz@MeVCiSAeBAiD?qe@MeEAaFA}WI_OEiA?qAAoe@M_LEkA?_C?uC?aEAiF?oLA}EA{B?{D@iH@uE@mb@GeECg`AMqFAy@?_QEoC@oCPgANgANmCl@mC~@iClAeD|AkFhCeGvCaUtKs@\\sHtDgb@lSyL`G{CvAcErBsQ~IgKdFkN~Ec`AhTcB^ib@lJwMvCq@|DUvASpAGZ}CzAyLrCsQhEeE`AuCx@qCjAmCzAiClBuLtI}AxAwA`BuAfBqAnBgX`c@`@vYeDbR]n@_B[O[o@bAy@v@{PbE}B^{Cd@eMlD{@z@eATuCToQtA}ZfAuPRel@Z}_@PexIC"
    let from = Self.places[0]
    let to = Self.places[1]
    let trip = Trip(from: from, to: to, encodedGeometry: encodedGeometry)
    return [trip]
  }()
}

func load<T: Decodable>(_ filename: String) -> T {
  let data: Data

  guard let file = Bundle.main.url(forResource: filename, withExtension: nil) else {
    fatalError("Couldn't find \(filename) in main bundle.")
  }

  do {
    data = try Data(contentsOf: file)
  } catch {
    fatalError("Couldn't load \(filename) from main bundle:\n\(error)")
  }

  do {
    let decoder = JSONDecoder()
    // pelias conventions are snake_case
    // TODO: account for this at a higher scope, otherwise we'll have to sprinkle it around here and in our client
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(T.self, from: data)
  } catch {
    fatalError("Couldn't parse \(filename) as \(T.self):\n\(error)")
  }
}
