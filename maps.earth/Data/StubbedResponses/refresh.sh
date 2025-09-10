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


fetch WALK
fetch TRANSIT
fetch BICYCLE
fetch CAR

fetch_bicycle_error

