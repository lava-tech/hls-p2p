var express = require('express');
var bodyParser = require('body-parser');
var morgan = require('morgan');
var redis = require('redis');
var redis_client = redis.createClient();

var app = express();
//app.use(morgan({ format: 'dev', immediate: true }));
app.use(bodyParser());


app.use(express.static(__dirname));
app.use(express.static(__dirname + '/public'));
app.use(function(req, res, next) {
    res.setHeader("Access-Control-Allow-Origin", "*");
    return next();
});

app.post('/remote_log', function(req, res){
   var data = req.body.log;

   console.log(data); 
   res.send('');
});

app.post('/peer_disconnect', function(req, res){
   var peer_id = req.body.peer_id;
   var app = req.body.app;

   console.log(peer_id + " disconnect from " + app);

   redis_client.lrem(app, 1, peer_id);
   res.send('');
});

app.get('/get_total_count', function(req, res){
    var resourceID = req.query.resourceID;
    
    redis_client.llen(resourceID, function(err, len){
        res.json(len);
    });
});

app.get('/get_peers', function(req, res){
   var resourceID = req.query.resourceID;
   var size = parseInt(req.query.size, 10);

   redis_client.llen(resourceID, function(err, len){
       if(len < size){
           redis_client.lrange(resourceID, 0, len - 1, function(err, items){
               res.json(items);
           })
       }
       else{
           var start = Math.floor((Math.random() * (len - 1)) + 1); 
           var end = start + size - 1;

           if(end >= len){
               end = len - 1;
           }

           var already_has = end - start + 1;
           var need_more = 0;
           if(already_has < size){
               need_more = size - already_has;
           }

           var ret = [];

           redis_client.lrange(resourceID, start, end, function(err, items){
               ret = ret.concat(items);
               if(need_more != 0){
                   redis_client.lrange(resourceID, 0, need_more - 1, function(err, items){
                       ret = ret.concat(items);
                       res.json(ret);
                   }) 
               }
               else{
                   res.json(ret);
               }
           });
       }
   });
});

app.listen(5000);
