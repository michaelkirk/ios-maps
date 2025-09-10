set -ex

# API_BASE="http://localhost:9000/travelmux/v6"
API_BASE="https://maps.earth/travelmux/v6"

# Fetch and format real responses from a locally running server - i.e. when the schema changes
function fetch {
    mode=$1
    output_prefix=$(echo "$mode" | tr '[:upper:]' '[:lower:]')
    # from realFine coffee in West Seattle to Zeitgeist downtown Seattle
    curl "${API_BASE}/plan?fromPlace=47.563412%2C-122.378248&toPlace=47.599091%2C-122.331856&numItineraries=5&mode=${mode}&preferredDistanceUnits=miles" | jq -S . > "${output_prefix}_plan.json"
}

function fetch_bicycle_error {
    mode=BICYCLE
    output_prefix=$(echo "$mode" | tr '[:upper:]' '[:lower:]')

    # from Los Angeles City Hall to Zeitgeist downtown Seattle
    # Bike routing isn't currently supported for that distance
    curl "${API_BASE}/plan?fromPlace=34.0536%2C-118.2430&toPlace=47.599091%2C-122.331856&numItineraries=5&mode=${mode}&preferredDistanceUnits=miles" | jq -S . > "${output_prefix}_plan_error.json"
}

function fetch_trip_elevation {
    # from realFine coffee in West Seattle to Zeitgeist downtown Seattle
    curl "${API_BASE}/elevation?path=gk%60vyAfeklhFgYsb%40%7B%40oAg%40oAS%7B%40%3F%7B%40%3Fg%40Rg%40g%40%3FcBRg%40oFkC_XRcL%3FkC%3FwG%3FgE%3F%7BO%3FoF%3FoF%3FsD%3FsN%3F_DRwB%3FwG%3FcQ%3FkCR%7BfAScL%7B%40wLoAgJSg%40wBsIcB%7BEkHsNsDsDSSoFsDwBcBkCoA%7B%40g%40%7BJ%7BEkHsDczBogA%7BO_I_I_Dg%40SoAg%40%3FoFSoi%40%3Fgc%40SgkA%3FoFgE%3Fo_%40%3Fg%40%3FwBcBg%40%7BE%3Fwo%40%3FklBSon%40%3F_N%3FsS%3F%7BY%3F%7BJ%3F%7BJ%3FoFcBS%7B%40%3FS%3F%7B%40SoASoAg%40kCcBwBoAsN%7BJgE_DwGgEsXkRkCwBg%40SSS%7B%40%7B%40oA%7B%40sXwQ_DkCgToP%7B%40%7B%40g%40oA%7B%40wBcBkH%7B%40oAsIoKcBwBoA_DwBsIoKgY%7B%40_Dg%40_D%7B%40cQf%40gTf%40kRz%40oi%40z%40gc%40%3FoFRkC%3FsD%3FwLSgEoAgESwBS%7BES%7BOg%40%7BzA%3F_DSce%40%3F%7BaA%3Fkz%40%3Fkk%40%3F_NScmASsv%40f%40o_%40%3FkCR%7B%40f%40%7B%40f%40Sf%40SSoAg%40sDg%40gESg%40Sg%40SwB%3FoA%3F_DS%3FwBz%40wBz%40g%40%3Fg%40SScBS_Iz%40%7BJ%3FSSSg%40S%7B%40%3FS%3FoAS%3FwB%3FgEf%40oP%3FSSSg%40%3Fg%40Sg%40%3Fg%40%3FSg%40g%40S%3Fg%40%3F%7B%40bBc%5BRkCRgER%7BERoKR%7BE%3Fg%40%3FkC%3FcBSkC%3F%7B%40ScB%3Fgw%40%3Fw%7E%40%3FwL%3F%7BT%3FgES%7BESsDoPgnB%3FoAR%7B%40zEwV%3FkC%3Fsq%40SwB%7B%40wBf%40g%40z%40oAf%40%7B%40RS%3F%7BE%3FwBScB_I%7B%40sXf%40sSf%40co%40vB_NRo_%40%3FkH%3FkHf%40%7BJvB_NnA_Nf%40%7BO%3FkH%3FsI%3FkrDg%40g%7EDnAsNRkxF%3Fwe%40g%40%7BJ%7B%40cGoA%7BEkCwG%7BEkMcQsIoKwBsD%7B%40oAsNoP%7BYcVsI%7BEcGsDsIsDwcAo_%40wLsD_IkC_D%7B%40gY_Iz%40cBkHoAoA%7B%40%3FoAgESkH%7B%40oKcBc%5BgJcGcBwVoF%7BJgE%7BT_IcQsDwBg%40_S_DwGSgESgToAsSg%40sg%40SsXRk_AoAoU%3F_I%3Fc%7E%40f%40oASSg%40%3FwB%3FsDoA%3FcB%3FcBgJ%7B%40cL%3FoF%3FsD%7B%40%7B%5E%3FgE%3F%7BY%3F%7BE%3FwG%3F_DRs%5D%3FkR%3FoK%3FkH%3FoF%3Fw%60%40%3Fs%5D%3FcB%3FgEgE%3Fcj%40g%40SzE%3FbBS%3FSRSR%3FfE" | jq -S . > "trip_elevation.json"
}

fetch WALK
fetch TRANSIT
fetch BICYCLE
fetch CAR

fetch_bicycle_error
fetch_trip_elevation

