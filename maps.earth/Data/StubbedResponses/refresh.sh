set -ex

function fetch {
    mode=$1
    output_prefix=$(echo "$mode" | tr '[:upper:]' '[:lower:]')
    curl "http://localhost:9000/travelmux/v2/plan?fromPlace=47.563412%2C-122.378248&toPlace=47.599091%2C-122.331856&numItineraries=5&mode=${mode}&preferredDistanceUnits=miles" | jq . > "${output_prefix}_plan.json"
}

fetch WALK
fetch TRANSIT
fetch BICYCLE
fetch CAR
