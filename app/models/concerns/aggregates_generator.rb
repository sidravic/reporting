class AggregatesGenerator
  def self.generate_daily_aggregates(date = nil)
    map = <<-MAP
        function(){
          var key = {date: new Date(this.record_created_at.getFullYear(),
                                    this.record_created_at.getMonth(),
                                    this.record_created_at.getDate(),
                                    this.record_created_at.getHours(),0,0,0)
                    };

          var data = {};
          data.zone = this.zone;
          data['zone_' + this.zone.toString()] = 1;
          data.service_type_string = this.service_type.toString().toLowerCase();
          data[this.service_type.toString().toLowerCase()] = 1;
          data.total_price_cents = parseInt(this.price_cents);
          data.shipment = this.tracking_id

          if(this.carrier == 'FEDEX'){
            data.FEDEX = 1;
            data.UPS = 0;
          }
          else{
            data.UPS = 1;
            data.FEDEX = 0;
          }


          emit(key, data);

        }
MAP


    reduce = <<-REDUCE

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
                      'zone_92': 0,
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

            var today = new Date()
            results.updated_at = new Date(today.getFullYear(),
                                          today.getMonth(),
                                          today.getDate(),
                                          today.getHours(),
                                          0,0,0)
            results.FEDEX += v.FEDEX;
            results.UPS += v.UPS;
        });


       return results;

  }

REDUCE


  finalize =  <<-FINALIZE
        function(key, results){
           var fields = [
                   'next_day_air',
                   'second_day',
                   'three_day_select',
                   'ground',
                   'fedex_ground',
                   'priority_overnight',
                   'fedex_express_saver',
                   'fedex_2_day',
                   'zone_2',
                   'zone_3',
                   'zone_4',
                   'zone_5',
                   'zone_6',
                   'zone_7',
                   'zone_8',
                   'zone_9',
                   'zone_10',
                   'zone_14',
                   'zone_17',
                   'zone_22',
                   'zone_23',
                   'zone_25',
                   'zone_92',
                   'zone_96',
                   'total_price_cents',
                   'UPS',
                   'FEDEX'
              ];


        fields.forEach(function(f){
           if(!results[f])
              results[f] = 0;
           });

          if(!results.shipments){
             results.shipments = [];
             results.shipments.push(results.shipment);
          }


        return results;


        }
    FINALIZE

    if date.nil?
      ReportingShipment.order_by([:record_created_at, :desc]).
          map_reduce(map, reduce).out(merge: 'daily_aggregates').finalize(finalize).find
    else
      ReportingShipment.where({:record_created_at.gte => date.beginning_of_day,
                               :record_created_at.lt => date.end_of_day}).
                      map_reduce(map,reduce).out(merge: 'daily_aggregates').find
    end
  end


  def self.generate_monthly_aggregates
    map = <<-MAP
      function(){
        var objDate = this._id.date;
        var key = {
                   year: objDate.getFullYear(),
                   month: objDate.getMonth()
                  }

        emit(key, this.value);
      }
    MAP


    reduce = <<-REDUCE
      function(key, values){
        var result = {
                        next_day_air:0,
                        second_day:0,
                        three_day_select:0,
                        ground:0,
                        fedex_ground:0,
                        priority_overnight:0,
                        fedex_express_saver:0,
                        fedex_2_day:0,
                        total_price_cents:0,
                        zone_2:0,
                        zone_3:0,
                        zone_4:0,
                        zone_5:0,
                        zone_6:0,
                        zone_7:0,
                        zone_8:0,
                        zone_9:0,
                        zone_10:0,
                        zone_14:0,
                        zone_17:0,
                        zone_22:0,
                        zone_23:0,
                        zone_25:0,
                        zone_92:0,
                        zone_96:0,
                        shipments:[]
                      };


       values.forEach(function(v){
          result.next_day_air += v.next_day_air;
          result.second_day += v.second_day;
          result.three_day_select += v.three_day_select;
          result.ground += v.ground;
          result.fedex_ground += v.fedex_ground;
          result.total_price_cents += parseInt(v.total_price_cents);
          result.shipments.push(v.shipments)
          result.zone_2 += v.zone_2;
          result.zone_3 += parseInt(v.zone_3);
          result.zone_4 += parseInt(v.zone_4);
          result.zone_5 += parseInt(v.zone_5);
          result.zone_6 += parseInt(v.zone_6);
          result.zone_7 += parseInt(v.zone_7);
          result.zone_8 += parseInt(v.zone_8);
          result.zone_9 += parseInt(v.zone_9);
          result.zone_10 += parseInt(v.zone_10);
          result.zone_14 += parseInt(v.zone_14);
          result.zone_17 += parseInt(v.zone_17);
          result.zone_22 += parseInt(v.zone_22);
          result.zone_23 += parseInt(v.zone_23);
          result.zone_25 += parseInt(v.zone_25);
          result.zone_92 += parseInt(v.zone_92);
          result.zone_96 += parseInt(v.zone_96);

      });

      return result;


      }
    REDUCE

    DailyAggregate.order_by([:_id, :desc]).map_reduce(map, reduce).
                  out(merge: 'monthly_aggregates')
  end
end