package 
{
    import adobe.utils.CustomActions;
    import com.tvie.osmf.p2p.data.Chunk;
    import com.tvie.osmf.p2p.data.ChunkCache;
    import com.tvie.osmf.p2p.peer.PeerMsg;
    import com.tvie.osmf.p2p.P2PLoader;
    import com.tvie.osmf.p2p.peer.PeerRespStatus;
    import com.tvie.osmf.p2p.tracker.HttpTracker;
    import com.tvie.osmf.p2p.utils.RemoteLogger;
	import flash.display.Sprite;
	import flash.events.Event;
    import flash.events.TimerEvent;
    import flash.net.URLVariables;
    import flash.utils.ByteArray;
    import flash.utils.Timer;
    import org.denivip.osmf.plugins.HLSPluginInfo;
    import org.osmf.containers.MediaContainer;
    import org.osmf.layout.LayoutMetadata;
    import org.osmf.media.DefaultMediaFactory;
    import org.osmf.media.MediaElement;
    import org.osmf.media.MediaFactory;
    import org.osmf.events.MediaFactoryEvent;
    import org.osmf.media.MediaPlayer;
    import org.osmf.media.PluginInfoResource;
    import org.osmf.media.URLResource;
    import org.osmf.utils.URL;
	
	/**
	 * ...
	 * @author dista
	 */
	public class Main extends Sprite 
	{
		
		public function Main():void 
		{
			if (stage) init();
			else addEventListener(Event.ADDED_TO_STAGE, init);
		}
        
        private function init2(e:Event = null):void {
            var url:URL = new URL("http://10.33.0.99");
            
            var x:int = 10;
            var m:String = "http://10.33.0.81:10080/kfkw/wd";
            var re:RegExp = /(\w+):\/\/([^\/]+)/ ;
            
            var xx:String = m.replace(re, "$1://" + url.host + ":" + url.port);
            trace(xx);
        }
        
        private function debugGetPieceData():void {
            var chunk:Chunk = new Chunk("abbb");
            chunk.pieceCount = 1;
            chunk.pieces[0].content = new ByteArray();
            chunk.pieces[0].content.length = 160552;
            chunk.pieces[0].chunkOffset = 0;
            chunk.pieces[0].isReady = true;
            
            chunk.calSize();
            
            var z:ByteArray = chunk.getPieceData(316780, -1);
            trace(z);
            return;
        }
        
        private function debugGetPieceData2():void {
            var chunk:Chunk = new Chunk("aaa");
            chunk.pieceCount = 5;
            
            chunk.pieces[0].content = new ByteArray();
            chunk.pieces[0].content.length = 105167;
            chunk.pieces[0].chunkOffset = 0;
            chunk.pieces[0].isReady = true;
            
            chunk.pieces[1].content = new ByteArray();
            chunk.pieces[1].content.length = 105167;
            chunk.pieces[1].chunkOffset = 105167;
            chunk.pieces[1].isReady = true;
            
            chunk.pieces[2].content = new ByteArray();
            chunk.pieces[2].content.length = 105167;
            chunk.pieces[2].chunkOffset = 210334;
            chunk.pieces[2].isReady = true;
            
            chunk.pieces[3].content = new ByteArray();
            chunk.pieces[3].content.length = 105167;
            chunk.pieces[3].chunkOffset = 315501;
            chunk.pieces[3].isReady = true;
            
            chunk.pieces[4].content = new ByteArray();
            chunk.pieces[4].content.length = 152168;
            chunk.pieces[4].chunkOffset = 420668;
            chunk.pieces[4].isReady = true;
            
            chunk.calSize();
            
            var z:ByteArray = chunk.getPieceData(191158, 95579);
            trace(z.length);
        }
        
        private function testUrl():void {
            var urlV:URLVariables = new URLVariables();
            urlV.x = ["192.168.0.100:8088",  "192.168.0.100:8099"];
            
            var p:String = urlV.toString();
            var u2:URLVariables = new URLVariables(p);
            trace(u2.x);
        }
        
        private function xpp(s:PeerRespStatus):Boolean {
            if(s.goPushChunks.length > 0) {
                var chunk:Chunk = s.goPushChunks[0];
                
                if (chunk.idx == (s.goPushIdx + 1)) {
                    s.goPushIdx++;
                    
                    s.goPushChunks.shift();
                    
                    return true;
                }
            }
            
            return false;
        }
        
        private function test_addToPendingPushChunks():void {
            var cc:ChunkCache = new ChunkCache();
            var c:Chunk = new Chunk("1");
            var c2:Chunk = new Chunk("2");
            var c3:Chunk = new Chunk("3");
            var s:PeerRespStatus = new PeerRespStatus();
            s.addToPendingPushChunks(c3);
            s.addToPendingPushChunks(c);
            s.addToPendingPushChunks(c2);
            s.goPushIdx = -1;
            while (true) {
                var ret:Boolean = xpp(s);
                
                if (!ret) {
                    break;
                }
            }
        }
		
		private function init(e:Event = null):void 
		{   
			removeEventListener(Event.ADDED_TO_STAGE, init);
			// entry point
            
            //var xxx:HttpTracker = new HttpTracker("http://192.168.1.106:5000/get_peers");
            //xxx.getPeers("ddd");
            
            //debugGetPieceData2();
            //return;
            
            //p2ploader = new P2PLoader("rtmfp://10.33.0.81:1935/app", new Vector.<String>());
            
            factory = new DefaultMediaFactory();
            factory.addEventListener(MediaFactoryEvent.PLUGIN_LOAD, onLoadPlugin);
            factory.addEventListener(MediaFactoryEvent.PLUGIN_LOAD_ERROR, onError);
            factory.loadPlugin(new PluginInfoResource(new HLSPluginInfo()));
            
            var url:String = "http://10.33.0.81/x.flv";
            var startParams:Object = this.root.loaderInfo.parameters;
            
            if (!startParams.hasOwnProperty("m3u8_url")) {
                startParams = new Object();
                startParams["m3u8_url"] = "http://10.33.0.81:40770/live/tt/ttx.m3u8";
                startParams["rtmfp_url"] = "rtmfp://10.33.0.81:19350/app";
                startParams["http_tracker"] = "http://10.33.0.81:5000/get_peers";
                startParams["remote_log_base_url"] = "http://10.33.0.81:5000/remote_log";
                startParams["rtmfp_url_peers"] = "2";
                startParams["index_rtmfp_url"] = "";
                startParams["index_rtmfp_url_peers"] = "1";
                startParams["source_servers"] = ["10.33.0.81:40770"]
            }
            
            var url2:String = "http://10.33.0.81:10099/live/tvie/mytest2/mxx.m3u8";
            url2 = startParams["m3u8_url"];
            DebugLogger.log(url2);
            //var params:URLVariables = new URLVariables();
            //params.source_servers = ["10.33.0.81:10099"];
            //url2 += "?" + params.toString();

            //url2 = "http://192.168.1.104/live/tvie/ax/multistream.m3u8";
            var res:URLResource = new URLResource(url2);
            res.addMetadataValue("rtmfp_url", startParams["rtmfp_url"]);
            res.addMetadataValue("http_tracker", startParams["http_tracker"]);  
            res.addMetadataValue("remote_log_base_url", startParams["remote_log_base_url"]);
            res.addMetadataValue("rtmfp_url_peers", parseInt(startParams["rtmfp_url_peers"], 10));
            res.addMetadataValue("index_rtmfp_url", startParams["index_rtmfp_url"]);
            res.addMetadataValue("index_rtmfp_url_peers", parseInt(startParams["index_rtmfp_url_peers"], 10));
            res.addMetadataValue("source_servers", startParams["source_servers"]);
            
            ele = factory.createMediaElement(res);
            
            var layout : LayoutMetadata = new LayoutMetadata();
            layout.width=600;
            layout.height=400;
            layout.x=100;
            layout.y = 100;

            ele.addMetadata(LayoutMetadata.LAYOUT_NAMESPACE, layout);
            
            player = new MediaPlayer();
            player.media = ele;
            player.autoPlay = true;
            player.volume = parseFloat(startParams["volume"]);
            container = new MediaContainer();
            container.addMediaElement(ele);
            
            addChild(container);
		}
        
        private function onLoadPlugin(e:Event):void {
            
        }
        
        private function onError(e:Event):void {
            
        }
        
        private var p2ploader:P2PLoader;
        private var ele:MediaElement
        
        private var factory:MediaFactory;
        private var player:MediaPlayer;
        private var sp:Sprite;
        private var container:MediaContainer;
		private var timer:Timer = new Timer(1000, 1);
	}
	
}