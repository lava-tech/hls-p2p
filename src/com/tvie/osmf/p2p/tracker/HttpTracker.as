package com.tvie.osmf.p2p.tracker 
{
    import com.tvie.osmf.p2p.events.TrackerEvent;
    import flash.events.Event;
    import flash.events.IOErrorEvent;
    import flash.net.URLLoader;
    import flash.net.URLLoaderDataFormat;
    import flash.net.URLRequest;
    import flash.net.URLRequestMethod;
    import flash.net.URLVariables;
	/**
     * ...
     * @author dista
     */
    public class HttpTracker extends TrackerBase 
    {
        private var loader_:URLLoader = null;
        private var url_:String;
        public function HttpTracker(url:String) 
        {
            url_ = url;
        }
        
        override public function getPeers(resourceID:String, size:int):void
        {
            DebugLogger.log("getPeers, resoueceID: " + resourceID + " size: " + size);
            
            if (loader_ != null) {
                loader_.removeEventListener(Event.COMPLETE, onDownloadCompleted);
                loader_.close();
            }
                                      
            var request:URLRequest = new URLRequest(url_);
            var params:URLVariables = new URLVariables();
            params.resourceID = resourceID;
            params.size = size;
            request.method = URLRequestMethod.GET;
            request.data = params;
            
            loader_ = new URLLoader();
            loader_.dataFormat = URLLoaderDataFormat.TEXT;
            loader_.addEventListener(Event.COMPLETE, onDownloadCompleted);
            loader_.addEventListener(IOErrorEvent.IO_ERROR, onDownloadFailed);
            
            loader_.load(request);
        }
        
        private function onDownloadCompleted(e:Event):void {
            var data:Array = JSON.parse(loader_.data) as Array;
            
            var event:TrackerEvent = new TrackerEvent(TrackerEvent.PEER_LIST);
            event.peers = new Vector.<String>();
            
            for (var i:int = 0; i < data.length; i++) {
                event.peers.push(data[i]);
            }
            
            dispatchEvent(event);
        }
        
        private function onDownloadFailed(e:IOErrorEvent):void {
            DebugLogger.log('IOError when get peers');
            
            var event:TrackerEvent = new TrackerEvent(TrackerEvent.PEER_LIST);
            event.peers = new Vector.<String>();
            
            dispatchEvent(event);
        }
    }

}