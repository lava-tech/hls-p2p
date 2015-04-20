package com.tvie.osmf.p2p 
{
    import adobe.utils.CustomActions;
    import com.tvie.osmf.p2p.data.Chunk;
    import com.tvie.osmf.p2p.data.ChunkCache;
    import com.tvie.osmf.p2p.data.ChunkState;
    import com.tvie.osmf.p2p.data.Piece;
    import com.tvie.osmf.p2p.events.ContentServerEvent;
    import com.tvie.osmf.p2p.events.P2PLoaderStatusEvent;
    import com.tvie.osmf.p2p.events.P2PNetworkEvent;
    import com.tvie.osmf.p2p.events.PublishPointEvent;
    import com.tvie.osmf.p2p.source.ContentServer;
    import com.tvie.osmf.p2p.source.IContentServerSelector;
    import com.tvie.osmf.p2p.source.RRContentServerSelector;
    import com.tvie.osmf.p2p.source.SelectorFactory;
    import com.tvie.osmf.p2p.utils.P2PSetting;
    import com.tvie.osmf.p2p.utils.RemoteLogger;
    import flash.display.ShaderInput;
    import flash.errors.IllegalOperationError;
    import flash.events.AsyncErrorEvent;
    import flash.events.DataEvent;
	import flash.events.EventDispatcher;
    import com.tvie.osmf.p2p.events.PeerStatusEvent;
    import __AS3__.vec.Vector;
    import flash.events.IEventDispatcher;
    import flash.events.IOErrorEvent;
    import flash.events.NetFilterEvent;
    import flash.events.NetStatusEvent;
    import flash.events.SecurityErrorEvent;
    import flash.events.TimerEvent;
    import flash.net.URLRequest;
    import flash.net.URLStream;
    import flash.utils.ByteArray;
    import flash.utils.getTimer;
    import flash.utils.IDataInput;
    import flash.utils.setTimeout;
    import flash.utils.Timer;
    import org.denivip.osmf.utility.Url;
    
	/**
     * ...
     * @author dista
     * 
     * using the class to load a piece from P2P network
     */
    public class P2PLoader extends Loader
    {
        
        public function P2PLoader(trackerAddr:String, chunkPeerCount:int, contentServers:Vector.<String>, dispatcher:IEventDispatcher,
                                  additionalInfo:Object, isSameResource:Boolean = false, chunkDuration:Number = 0) 
        {
            dispatcher_ = dispatcher;
            contentServers_ = contentServers;
            additionalInfo_ = additionalInfo;
            
            isSameResource_ = isSameResource;
            
            RemoteLogger.baseUrl = additionalInfo['remote_log_base_url'];
            
            if (isSameResource && chunkPeerCount != 1) {
                throw new ArgumentError("when isSameResource is true, chunkPeerCount can only be 1");
            }
            
            P2PSetting.CHUNK_PEERS_COUNT = chunkPeerCount;
            P2PSetting.MAX_TRANSFER_TIME_FOR_PIECE = chunkDuration * 1000;
            P2PSetting.GET_CHUNK_FIRST_TIMEOUT = chunkDuration * 1000;
            P2PSetting.CHUNK_DURATION = chunkDuration * 1000;
            
            selector_ = selectorFactory_.createSelector(SelectorFactory.RR_SELECTOR, contentServers,
                                                        "http");
            sessionTimer_ = new Timer(P2PSetting.SESSION_CONNECTION_TIMEOUT, 1);
            sessionTimer_.addEventListener(TimerEvent.TIMER_COMPLETE, onSessionConnectTimeout);
            sessionTimer_.start();
            
            var idx:int = 0;
            for (var i:int = (trackerAddr.length - 1); i >= 0; i--) {
                if (trackerAddr.charAt(i) == '/') {
                    idx = i;
                    break;
                }
            }
            
            var resourceName:String = trackerAddr.substring(idx + 1);
            var tracker:String = trackerAddr.substring(0, idx);
            
            for (i = 0; i < sessionNumber_; i++) {
                var session:RtmfpSession = new RtmfpSession();
                session.maxPeerConnections = P2PSetting.SESSION_MAX_PEER_CONNECTIONS;
                session.addEventListener(NetStatusEvent.NET_STATUS, onSessionNetStatus);
                session.addEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);
                session.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
                session.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
                
                sessions_.push(session);
                sessionStates_.push( -1);
                session.connect(tracker, resourceName);
            }
            
            csDispatcher_.addEventListener(ContentServerEvent.STATUS, onContentServerStatus);
            
            chunkCache_ = new ChunkCache();
        }
        
        private function onContentServerStatus(event:ContentServerEvent):void {
            var chunk:Chunk = chunkCache_.findChunk(lastReq_.url);
            var piece:Piece = chunk.pieces[0];
            switch(event.code) {
                case ContentServerEvent.PROGRESS:
                    if (piece.content == null) {
                        piece.content = new ByteArray();
                    }
                    event.data.readBytes(piece.content, piece.content.length);
                    if (p2pNetwork_) {
                        // TODO: may be we need to change the frequency of updating
                        if (!P2PSetting.LIMIT_DOWNLOAD_PROGRESS_EVENT) {
                            p2pNetwork_.chunkUpdated(chunk);
                        }
                        else {
                            if (piece.content.length - lastUpdateBytes_ >= P2PSetting.LIMIT_DOWNLOAD_PROGRESS_EVENT_BYTES) {
                                p2pNetwork_.chunkUpdated(chunk);
                                lastUpdateBytes_ = piece.content.length;
                            }
                        }
                    }
                    break;
                case ContentServerEvent.COMPLETE:
                    piece.isReady = true;
                    piece.contentLength = piece.content.length;
                    piece.chunkOffset = 0;
                    chunk.calSize();
                    chunk.state = ChunkState.LOAD_FROM_SOURCE_DONE;
                   
                    if (p2pNetwork_) {
                        p2pNetwork_.chunkUpdated(chunk);
                    }

                    break;
                case ContentServerEvent.ERROR:
                    DebugLogger.log(logPrefix + "[S] download " + lastReq_.url + " failed");
                    RemoteLogger.log(logPrefix + "[S] download " + lastReq_.url + " failed");
                    chunk.isError = true;
                    break;
            }
        }
        
        private function doLoad(request:URLRequest, dispatcher:IEventDispatcher, timeout:int):void {
            close();
            
            if (chunkCache_.length > P2PSetting.MAX_CHUNK_COUNT) {
                chunkCache_.removeOldest();
            }
            
            if (getFromHttpServer_ && changeToP2PState_ == CTP_OK) {
                RemoteLogger.log(logPrefix + "will download data from http server to p2p network");
                getFromHttpServer_ = false;
                
                JavascriptCall.set_source_change("peers");
            }
            
            if (getFromHttpServer_) {
                if (changeToP2PState_ == CTP_WAIT_FOR_NEXT_OPEN) {
                    changeToP2PState_ = CTP_WAIT_ENOUGH_PEERS;
                    p2pNetwork_.changeToP2P(changeToP2PRequest_.url);
                }
                else if (changeToP2PState_ == CTP_FAILED)
                {
                    changeToP2PState_ = CTP_INIT;
                }
                
                if (contentServer_) {
                    contentServer_.close();
                }
                
                contentServer_ = selector_.select();
                
                lastFrom_ = FROM_CONTENT_SERVER;
                
                var chunk:Chunk = chunkCache_.findChunk(request.url);
                
                if (!chunk) {
                    chunk = new Chunk(request.url);

                    if (changeToP2PState_ == CTP_INIT && canChangeToP2P()) {
                        changeToP2PState_ = CTP_WAIT_FOR_NEXT_OPEN;
                        isFromStableSource_ = false;
                        changeToP2PRequest_ = request;
                    }
                    
                    chunk.isFromStableSource = isFromStableSource_;
                    chunk.state = ChunkState.LOADING_FROM_SOURCE;
                    chunkCache_.addChunk(chunk);
                    
                }
                else {
                    chunk.isFromStableSource = isFromStableSource_;
                    chunk.isError = false;
                    chunk.state = ChunkState.LOADING_FROM_SOURCE;            
                }
                
                chunk.pieceCount = 1;
                chunk.pieces[0].pieceID = 0;
                
                DebugLogger.log(logPrefix + "[S]getChunk " + request.url);
                contentServer_.open2(request, dispatcher, timeout, csDispatcher_);
            }
            else {
                lastFrom_ = FROM_P2P;
                DebugLogger.log(logPrefix + "[P]getChunk " + request.url);
                p2pNetwork_.getChunk(request.url, dispatcher, timeout);
            }
        }
        
        private function onP2PNetworkStatus(event:P2PNetworkEvent):void {
            if (event.code == P2PNetworkEvent.CONNECT_ACTIVE_PEERS_DONE) {
                if (!getPeerListOk_) {
                    RemoteLogger.log(logPrefix + "connect peers, use: " + ((new Date()).getTime() - p2pNetworkCreateTime_) + "ms");
                    getPeerListOk_ = true;
                    if (pendingReq_) {
                        p2pNetwork_.findPeers(pendingReq_.url);
                    }
                }
            }
            else if (event.code == P2PNetworkEvent.GET_PEERS_OK
                    || event.code == P2PNetworkEvent.GET_PEERS_ERROR){
                sourceDetermined_ = true;
                if (event.code == P2PNetworkEvent.GET_PEERS_OK) {
                    DebugLogger.log(logPrefix + "will get from peers");
                    RemoteLogger.log(logPrefix + "will get from peers");
                    getFromHttpServer_ = false;
                    
                    JavascriptCall.set_source_change("peers");
                }
                else if (event.code == P2PNetworkEvent.GET_PEERS_ERROR) {
                    DebugLogger.log(logPrefix + "will get from http server");
                    getFromHttpServer_ = true;
                    RemoteLogger.log(logPrefix + "will get from http server");
                    
                    resetChangeToP2PStates();
                    
                    JavascriptCall.set_source_change("server");
                }
                
                if (pendingReq_) {
                    doLoad(pendingReq_, pendingDispatcher_, pendingTimeout_);
                    pendingReq_ = null;
                }
            }
            else if (event.code == P2PNetworkEvent.NETWORK_ERROR) {
                getFromHttpServer_ = true;

                DebugLogger.log(logPrefix + "p2p network error, will get from http server");
                RemoteLogger.log(logPrefix + "p2p network error, will get from http server");
                
                resetChangeToP2PStates();
                
                JavascriptCall.set_source_change("server");
                
                doLoad(lastReq_, lastDispatcher_, lastTimeout_);
            }
            else if (event.code == P2PNetworkEvent.CHANGE_TO_P2P_ERROR) {
                changeToP2PState_ = CTP_FAILED;
                changeToP2PFailedTime_ = getTimer();
                isFromStableSource_ = true;
            }
            else if (event.code == P2PNetworkEvent.CHANGE_TO_P2P_OK) {
                DebugLogger.log(logPrefix + "change to p2p network ok");
                RemoteLogger.log(logPrefix + "change to p2p network ok");
                changeToP2PState_ = CTP_OK;
            }
            else if (event.code == P2PNetworkEvent.IDX_NOT_READY) {
                isIdxReady_ = false;
            }
            else if (event.code == P2PNetworkEvent.IDX_READY) {
                isIdxReady_ = true;
            }
        }
        
        private function findSessionIdx(session:RtmfpSession):int {
            for (var i:int = 0; i < sessions_.length; i++) {
                if (sessions_[i] == session) {
                    return i;
                }
            }
            
            // should never happen
            return -1;
        }
        
        private function isAllSessionReady():Boolean {
            var allReady:Boolean = true;
            for (var i:int = 0; i < sessionStates_.length; i++) {
                if (sessionStates_[i] != 1) {
                    allReady = false;
                }
            }
            
            return allReady;
        }
        
        private function onSessionNetStatus(event:NetStatusEvent):void {
            var session:RtmfpSession = event.target as RtmfpSession;
            var idx:int = findSessionIdx(session);
            if(sessionTimer_.running){
                sessionTimer_.stop();
            }
            
            DebugLogger.log(logPrefix + "P2PLoader: onSessionNetStatus. code: " + event.info.code);
            switch(event.info.code) {
                case "NetConnection.Connect.Success":
                    sessionStates_[idx] = 1;
                    //DebugLogger.log(event.info.code);
                    JavascriptCall.set_app_peer_id(sessions_[idx].resouceName, sessions_[idx].nearID);
                    session.removeEventListener(NetStatusEvent.NET_STATUS, onSessionNetStatus);
                    break;
                case "NetStream.Connect.Closed":
                    DebugLogger.log(logPrefix + "Stream: " + event.info.stream.farID);
                    break;
                case "NetConnection.Connect.Closed":
                    sessionStates_[idx] = 0;
                    var e:P2PLoaderStatusEvent = new P2PLoaderStatusEvent(P2PLoaderStatusEvent.ON_STATUS, false,
                        false, P2PLoaderStatusEvent.CONNECTION_CLOSE);
                    dispatcher_.dispatchEvent(e);
                    break;
                case "NetConnection.Connect.Failed":
                    sessionStates_[idx] = 0;
                    var ef:P2PLoaderStatusEvent = new P2PLoaderStatusEvent(P2PLoaderStatusEvent.ON_STATUS, false,
                        false, P2PLoaderStatusEvent.CONNECTION_FAILED);
                    dispatcher_.dispatchEvent(ef);
                    break;
                default:
                    break;
            }
            
            if (isAllSessionReady()) {
                if (p2pNetwork_ != null) {
                    throw new Error("P2PNetwork already initialized");
                }
                p2pNetwork_ = new DefaultP2PNetwork(sessions_[0], contentServers_, chunkCache_, 
                            additionalInfo_, isSameResource_);
                p2pNetworkCreateTime_ = (new Date()).getTime();
                p2pNetwork_.addEventListener(P2PNetworkEvent.STATUS, onP2PNetworkStatus);
            }
        }

        private function onAsyncError(event:AsyncErrorEvent):void {
            DebugLogger.log(logPrefix + "onAsyncError");
        }
        
        private function onIOError(event:IOErrorEvent):void {
            DebugLogger.log(logPrefix + "onIOError");
        }
        
        private function onSecurityError(event:SecurityErrorEvent):void {
            DebugLogger.log(logPrefix + "onSecurityError");
        }
        
        private function onSessionConnectTimeout(event:TimerEvent):void {
            for (var i:int = 0; i < sessionNumber_; i++) {
                var session:RtmfpSession = sessions_[i];
                JavascriptCall.set_app_peer_id(sessions_[i].resouceName, null);
                session.removeEventListener(NetStatusEvent.NET_STATUS, onSessionNetStatus);
                session.close();
                session = null;
            }
            
            sessions_.splice(0, sessions_.length);
         
            sourceDetermined_ = true;
            getFromHttpServer_ = true;
            
            resetChangeToP2PStates();
            
            DebugLogger.log(logPrefix + "will get from http server, reason: connect session timeout");
            RemoteLogger.log(logPrefix + "will get from http server, reason: connect session timeout");
            
            JavascriptCall.set_source_change("server");
            
            if (pendingReq_) {
                doLoad(pendingReq_, pendingDispatcher_, pendingTimeout_);
            }
            
            var e:P2PLoaderStatusEvent = new P2PLoaderStatusEvent(P2PLoaderStatusEvent.ON_STATUS, false,
                false, P2PLoaderStatusEvent.CONNECTION_TIMEOUT);
            dispatcher_.dispatchEvent(e);
        }
        
        /* Start of Loader functions */
        override public function get isOpen():Boolean
		{
			if (lastFrom_ == FROM_CONTENT_SERVER) {
                return contentServer_.isOpen;
            }
            else if (lastFrom_ == FROM_P2P) {
                return p2pNetwork_.isOpen;
            }
            
            return false;
		}
        
        override public function get isComplete():Boolean
		{
			if (lastFrom_ == FROM_CONTENT_SERVER) {
                return contentServer_.isComplete;
            }
            else if (lastFrom_ == FROM_P2P) {
                return p2pNetwork_.isComplete;
            }
            
            return false;
		}
        
        override public function get hasData():Boolean
		{
			if (lastFrom_ == FROM_CONTENT_SERVER) {
                return contentServer_.hasData;
            }
            else if (lastFrom_ == FROM_P2P) {
                return p2pNetwork_.hasData;
            }
            
            return false;
		}
        
        override public function get hasErrors():Boolean
		{
			if (lastFrom_ == FROM_CONTENT_SERVER) {
                return contentServer_.hasErrors;
            }
            else if (lastFrom_ == FROM_P2P) {
                return p2pNetwork_.hasErrors;
            }
            
            return false;
		}
        
        override public function get downloadDuration():Number
		{
			if (lastFrom_ == FROM_CONTENT_SERVER) {
                return contentServer_.downloadDuration;
            }
            else if (lastFrom_ == FROM_P2P) {
                return p2pNetwork_.downloadDuration;
            }
            
            return 0;
		}
        
        override public function canGetIdx():Boolean {
            if (getFromHttpServer_ || chunkCache_.isIdxTooOld()) {
                return false;
            }
            
            return isIdxReady_;
        }
        
        override public function getIdx(request:URLRequest):void {
            setTimeout(onGetIdx, 60, request);
        }
        
        private function onGetIdx(request:URLRequest):void {
            var e:P2PLoaderStatusEvent = new P2PLoaderStatusEvent(P2PLoaderStatusEvent.ON_STATUS);
            e.code = P2PLoaderStatusEvent.IDX_GOT;
            e.idxData = chunkCache_.indexData;
            e.request = request;
            
            dispatchEvent(e);
        }
        
        override public function get downloadBytesCount():Number
		{
			if (lastFrom_ == FROM_CONTENT_SERVER) {
                return contentServer_.downloadBytesCount;
            }
            else if (lastFrom_ == FROM_P2P) {
                return p2pNetwork_.downloadBytesCount;
            }
            
            return 0;
		}
        
        override public function get totalAvailableBytes():int {
            if (lastFrom_ == FROM_CONTENT_SERVER) {
                return contentServer_.totalAvailableBytes;
            }
            else if (lastFrom_ == FROM_P2P) {
                return p2pNetwork_.totalAvailableBytes;
            }
            
            return 0;
        }
        
        override public function getBytes(numBytes:int = 0):IDataInput {
            if (lastFrom_ == FROM_CONTENT_SERVER) {
                var bytes:IDataInput = contentServer_.getBytes(numBytes);
                return bytes;
            }
            else if (lastFrom_ == FROM_P2P){
                return p2pNetwork_.getBytes(numBytes);
            }
            
            return null;
        }
        
        override public function clearSavedBytes():void {
            if (lastFrom_ == FROM_CONTENT_SERVER) {
                return contentServer_.clearSavedBytes();
            }
            else if (lastFrom_ == FROM_P2P){
                return p2pNetwork_.clearSavedBytes();
            }
        }
        
        override public function appendToSavedBytes(source:IDataInput, count:uint):void {
            if (lastFrom_ == FROM_CONTENT_SERVER) {
                return contentServer_.appendToSavedBytes(source, count);
            }
            else if (lastFrom_ == FROM_P2P){
                return p2pNetwork_.appendToSavedBytes(source, count);
            }
        }
        
        override public function saveRemainingBytes():void {
            if (lastFrom_ == FROM_CONTENT_SERVER) {
                return contentServer_.saveRemainingBytes();
            }
            else if (lastFrom_ == FROM_P2P){
                return p2pNetwork_.saveRemainingBytes();
            }
        }
        
        override public function setIndexData(data:ByteArray):void {
            chunkCache_.indexData = data;
        }
        
        override public function toString():String {
            return "P2PLoader";
        }
        
        override public function open(request:Object, dispatcher:IEventDispatcher, timeout:Number):void
        {
            lastReq_ = request as URLRequest;
            //RemoteLogger.log(logPrefix + "open " + lastReq_.url);
            
            if (!sourceDetermined_) {
                pendingReq_ = request as URLRequest;
                pendingDispatcher_ = dispatcher;
                pendingTimeout_ = timeout;
                pendingTimer_ = new Timer(pendingTimeout_, 1);
                pendingTimer_.addEventListener(TimerEvent.TIMER_COMPLETE, onPendingTimerComplete);
                if(getPeerListOk_){
                    p2pNetwork_.findPeers(pendingReq_.url);
                }
                else {
                    // p2pNetwork is not ready, so wait it ready
                }
                return;
            }
            doLoad(request as URLRequest, dispatcher, timeout);
        }
        
        private function onPendingTimerComplete(event:TimerEvent):void {
            
        }
        
        override public function close(dispose:Boolean = false):void {
            if (lastFrom_ == FROM_CONTENT_SERVER) {
                contentServer_.close(dispose);
            }
            else if (lastFrom_ == FROM_P2P) {
                p2pNetwork_.close(dispose);
            }
            
            // TODO: maybe we need to delete more
            if (dispose) {
                for (var i:int = 0; i < sessions_.length; i++) {
                    sessions_[i].close();
                }
            }
            
            lastUpdateBytes_ = 0;
        }
        
        private function resetChangeToP2PStates():void {
            isFromStableSource_ = true;
            changeToP2PStartTime_ = -1;
            changeToP2PFailedTime_ = getTimer();
            changeToP2PState_ = CTP_INIT;
            changeToP2PRequest_ = null;
        }
        
        private function canChangeToP2P():Boolean {
            if (sessions_.length <= 0) {
                return false;
            }
            
            var now:int = getTimer();
            
            if ((now - changeToP2PFailedTime_) < P2PSetting.CHANGE_TO_P2P_RETRY_TIME) {
                return false;
            }
            
            var stats:Object = (p2pNetwork_ as DefaultP2PNetwork).getPeerCountByGroup();
            
            // there are pieces need to be pushed to other peers
            if (stats['out'] != 0) {
                return false;
            }
            
            // now we can start to change
            return true;
        }
        
        private function get logPrefix():String {
            if (logPrefix_ != null) {
               return logPrefix_; 
            }
            
            if (sessions_.length > 0 && sessions_[0].connected) {
                logPrefix_ = sessions_[0].sessionID + " P2PLoader ";
            }
            
            if (logPrefix_ == null) {
                return "";
            }
            
            return logPrefix;
        }
         
        /* End of Loader functions */
        
        private var p2pNetwork_:P2PNetworkBase = null;
        private var getPeerListOk_:Boolean = false;
        
        private var getFromHttpServer_:Boolean = false;
        private var isFromStableSource_:Boolean = true;
        private var sessionTimer_:Timer;
        
        private var chunkCache_:ChunkCache;
        private var sourceDetermined_:Boolean = false;
        
        private var lastReq_:URLRequest = null;
        
        private var pendingReq_:URLRequest = null;
        private var pendingDispatcher_:IEventDispatcher = null;
        private var pendingTimeout_:int;
        private var pendingTimer_:Timer;
        
        private var lastDispatcher_:IEventDispatcher;
        private var lastTimeout_:int;
        
        private var lastFrom_:int = FROM_UNKNOWN; // -1: NO-VALUE, 0 FROM ContentServer, 1 FROM p2p
        private static const FROM_UNKNOWN:int = -1;
        private static const FROM_CONTENT_SERVER:int = 0;
        private static const FROM_P2P:int = 1;
        
        private var selectorFactory_:SelectorFactory = new SelectorFactory();
        private var selector_:IContentServerSelector = null;
        private var contentServer_:ContentServer = null;
        
        private var dispatcher_:IEventDispatcher;
        
        private var openDispatcherEventAttached_:Boolean = false;
        private var csDispatcher_:EventDispatcher = new EventDispatcher();
        
        private var lastUpdateBytes_:int = 0;
        private var contentServers_:Vector.<String> = null;
        
        private var changeToP2PStartTime_:int = 1;
        private var changeToP2PFailedTime_:int;
        private var changeToP2PRequest_:URLRequest;
        private var changeToP2PState_:String;
        private static const CTP_INIT:String = "init";
        private static const CTP_WAIT_FOR_NEXT_OPEN:String = "wait_for_next_open";
        private static const CTP_WAIT_ENOUGH_PEERS:String = "wait_enough_peers";
        private static const CTP_FAILED:String = "failed";
        private static const CTP_OK:String = "OK";
        
        private var p2pNetworkCreateTime_:Number;
        
        private var sessions_:Vector.<RtmfpSession> = new Vector.<RtmfpSession>();
        private var sessionStates_:Vector.<int> = new Vector.<int>();
        private var sessionNumber_:int = 1;
        
        private var logPrefix_:String = null;
        private var isSameResource_:Boolean;
        
        private var additionalInfo_:Object;
        private var isIdxReady_:Boolean = true;
    }

}