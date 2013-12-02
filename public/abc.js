
function(key, values){
var results = {'next_day_air': 0,
    'second_day': 0,
    'three_day_select': 0,
    'ground': 0,
    'fedex_ground':0,
    'priority_overnight':0,
    'fedex_express_saver':0,
    'fedex_2_day': 0,
    'zone_2': 0,
    'zone_3': 0,
    'zone_4': 0,
    'zone_5': 0,
    'zone_6': 0,
    'zone_7': 0,
    'zone_8': 0,
    'zone_9': 0,
    'zone_10': 0,
    'zone_14': 0,
    'zone_17': 0,
    'zone_22': 0,
    'zone_23': 0,
    'zone_25': 0,
    'zone_96': 0,
    'total_price_cents': 0,
    'UPS': 0,
    'FEDEX':0,
    'shipments':[]
};

values.forEach(function(v){
    results.shipments.push(v.shipment);
    results.total_price_cents += parseInt(v.total_price_cents);
    results[v.service_type_string] += v[v.service_type_string];
    results['zone_' + v.zone.toString()] += v['zone_' + v.zone.toString()];

    if (v.carrier == 'FEDEX')
        results.FEDEX += 1;
    else
        results.UPS += 1;

    var zone = v.zone;
    results['zone_' + zone.toString()] += 1
});

return results

}