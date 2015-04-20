package com.tvie.osmf.p2p 
{
    import com.tvie.osmf.p2p.data.Chunk;
    import com.tvie.osmf.p2p.data.ChunkCache;
    import com.tvie.osmf.p2p.data.ChunkState;
    import com.tvie.osmf.p2p.data.Piece;
    import com.tvie.osmf.p2p.events.P2PNetworkEvent;
    import com.tvie.osmf.p2p.events.P2PNetworkRepairerEvent;
    import com.tvie.osmf.p2p.events.PeerMsgErrorEvent;
    import com.tvie.osmf.p2p.events.PeerMsgEvent;
    import com.tvie.osmf.p2p.events.PeerStatusEvent;
    import com.tvie.osmf.p2p.events.PeerTestEvent;
    import com.tvie.osmf.p2p.events.PublishPointEvent;
    import com.tvie.osmf.p2p.events.TrackerEvent;
    import com.tvie.osmf.p2p.peer.PeerMsg;
    import com.tvie.osmf.p2p.peer.PeerReqStatus;
    import com.tvie.osmf.p2p.peer.PeerStatus;
    import com.tvie.osmf.p2p.source.ContentServer;
    import com.tvie.osmf.p2p.source.IContentServerSelector;
    import com.tvie.osmf.p2p.source.SelectorFactory;
    import com.tvie.osmf.p2p.tracker.TrackerBase;
    import com.tvie.osmf.p2p.tracker.TrackerFactory;
    import com.tvie.osmf.p2p.peer.Peer;
    import com.tvie.osmf.p2p.peer.PublishPoint;
    import com.tvie.osmf.p2p.utils.DictionaryUtil;
    import com.tvie.osmf.p2p.utils.P2PSetting;
    import com.tvie.osmf.p2p.utils.RemoteLogger;
    import flash.events.AsyncErrorEvent;
    import flash.events.IEventDispatcher;
    import flash.events.IOErrorEvent;
    import flash.events.NetFilterEvent;
    import flash.events.NetStatusEvent;
    import flash.events.SecurityErrorEvent;
    import flash.events.TimerEvent;
    import flash.geom.PerspectiveProjection;
    import flash.sampler.NewObjectSample;
    import flash.utils.ByteArray;
    import flash.utils.Dictionary;
    import flash.utils.getTimer;
    import flash.utils.IDataInput;
    import flash.utils.Timer;
    import org.denivip.osmf.utility.Url;
    import org.osmf.events.HTTPStreamingEvent;
    import org.osmf.events.HTTPStreamingEventReason;
	import org.osmf.net.httpstreaming.flv.FLVTagScriptDataMode;
    import org.osmf.net.httpstreaming.HTTPStreamDownloader;
    import org.osmf.utils.URL;
	/**
     * ...
     * @author dista
     */
    public class DefaultP2PNetwork extends P2PNetworkBase 
    {
        /*
         * @param session Established RtmfpSession 
         */
        public function DefaultP2PNetwork(session:RtmfpSession, contentServers:Vector.<String>, chunkCache:ChunkCache,
                                          additionalInfo:Object, isSameResouce:Boolean) 
        {
            super();
            
            qualifiedPeerCount_ = P2PSetting.CHUNK_PEERS_COUNT;
            
            chunkCache_ = chunkCache;
            
            contentServers_ = contentServers;
            
            additionalInfo_ = additionalInfo;
			
            session_ = session;
            session_.addEventListener(AsyncErrorEvent.ASYNC_ERROR, onSessionAsyncError);
            session_.addEventListener(IOErrorEvent.IO_ERROR, onSessionIOError);
            session_.addEventListener(NetStatusEvent.NET_STATUS, onSessionNetStatus);
            session_.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSessionSecurityError);
            publishPoint_ = new PublishPoint(session_, true, this);
            publishPoint_.addEventListener(PublishPointEvent.PUBLISH_START, onPublishStart);
            publishPoint_.addEventListener(PublishPointEvent.NEW_PEER_CONNECTED, onPublishPointHasPeer);
            publishPoint_.publish();
            
            repairer_ = new P2PNetworkRepairer(this, contentServers_);
            repairer_.addEventListener(P2PNetworkRepairerEvent.ON_STATUS, onRepaireStatus);
            repaireTimer_ = new Timer(REPAIRE_INTERVAL, 1);
            repaireTimer_.addEventListener(TimerEvent.TIMER_COMPLETE, onRepaireProcess);
            repaireTimer_.start();
            
            cleanUnUsedPeerTimer_ = new Timer(CUUPT_INTERVAL, 0);
            cleanUnUsedPeerTimer_.addEventListener(TimerEvent.TIMER, onCleanUnUsedPeer);
            cleanUnUsedPeerTimer_.start();
            
            setStatisticsTimer_ = new Timer(10000, 0);
            setStatisticsTimer_.addEventListener(TimerEvent.TIMER, onSetStatistics);
            setStatisticsTimer_.start();
        }
        
        private function onSetStatistics(event:TimerEvent):void {
            JavascriptCall.set_peers_statistics(peers_);
        }
        
        private function onCleanUnUsedPeer(event:TimerEvent):void {
            var now:int = getTimer();
            for (var k:String in peers_) {
                var peer:Peer = peers_[k];
                
                if (peer.reqStatus.closeSent) {
                    peer.normalClose = false;
                    onPeerClose(peer.id);
                }
                else if (peer.canBeRemoved && peer.connectFinishTime != -1 
                        && (now - peer.connectFinishTime) > 60000) {
                    // TODO: do something
                    DebugLogger.log(logPrefix + "remove peer.id=" + peer.id);
                    peer.reqClose();
                    peer.normalClose = true;
                    peer.reqStatus.closeSent = true;
                }
            }
        }
        
        private function stopPush():void {
            for (var k:String in peers_) {
                var peer:Peer = peers_[k];
                if(peer.reqStatus.mode != PeerStatus.PULL_MODE){
                    peer.reqStatus.mode = PeerStatus.PULL_MODE;
                    peer.reqStopPush("");
                }
            }
        }
        
        private function onRepaireStatus(event:P2PNetworkRepairerEvent):void {
            if (isFakeFailedPeers_)
            {
                var p2pNetworkEvent:P2PNetworkEvent = new P2PNetworkEvent(P2PNetworkEvent.STATUS);
                if (event.code == P2PNetworkRepairerEvent.REPAIR_OK) {
                    isPullMode_ = false;
                    p2pNetworkEvent.code = P2PNetworkEvent.CHANGE_TO_P2P_OK;
                }
                else if (event.code == P2PNetworkRepairerEvent.REPAIR_ERROR) {
                    stopPush();
                    p2pNetworkEvent.code = P2PNetworkEvent.CHANGE_TO_P2P_ERROR;
                }
                
                dispatchEvent(p2pNetworkEvent);
            }
            else {
                for (var i:int = 0; i < event.failedPeers.length; i++) {
                    onPeerClose(event.failedPeers[i].id);
                }
                            
                if (event.code == P2PNetworkRepairerEvent.REPAIR_OK) {
                    for (i = (needRepaireStates_.length - 1); i >= 0; i--) {
                        if (needRepaireStates_[i] == 1) {
                            needRepaireStates_.splice(i, 1);
                            needRepairePeers_.splice(i, 1);
                        }
                    }
                                                
                    if (needRepairePeers_.length == 0) {
                        needRepaire_ = false;
                        var chunk:Chunk = chunkCache_.getNewestReadyChunk();
                        if (chunk) {
                            for (var k:String in peers_) {
                                var peer:Peer = peers_[k];
                                if (peer.reqStatus.isUsed && peer.reqStatus.mode == PeerStatus.PUSH_MODE_PAUSED) {
                                    peer.reqResumePush(chunk.uri);
                                    
                                    peer.reqStatus.mode = PeerStatus.PUSH_MODE;
                                }
                            }
                        }
                        status_ = NETWORK_JOINED;
                    }
                }
                else if (event.code == P2PNetworkRepairerEvent.REPAIR_ERROR) {
                    blockRepair_ = true;
                    status_ = NETWORK_ERROR;
                    
                    stopPush();
                    
                    needRepaireStates_.splice(0, needRepaireStates_.length);
                    needRepairePeers_.splice(0, needRepairePeers_.length);
                    needRepaireUrl_ = null;
                    needRespPingIds_.splice(0, needRespPingIds_.length);
                    needRespSpeedTestIds_.splice(0, needRespSpeedTestIds_.length);
                    
                    var networkError:P2PNetworkEvent = new P2PNetworkEvent(P2PNetworkEvent.STATUS);
                    networkError.code = P2PNetworkEvent.NETWORK_ERROR;
                    
                    dispatchEvent(networkError);
                }
                else if (event.code == P2PNetworkRepairerEvent.REPAIR_DATA_ERROR)
                {
                    RemoteLogger.log(logPrefix_ + "repair data for " + event.failedDataUrl + " error");
                    var c:Chunk = chunkCache_.findChunk(event.failedDataUrl);
                    
                    if (c) {
                        c.isError = true;
                    }
                    
                    hasErrors_ = true;
                    isComplete_ = false;
                    
                    if (dispatcher_) {
                    	var streamingEvent:HTTPStreamingEvent = new HTTPStreamingEvent(
					        HTTPStreamingEvent.DOWNLOAD_ERROR,
					        false, // bubbles
					        false, // cancelable
                            0, // fragment duration
                            null, // scriptDataObject
                            FLVTagScriptDataMode.NORMAL, // scriptDataMode
                            event.failedDataUrl, // urlString
                            0, // bytesDownloaded
                            event.failedDataReason, // reason
                            null /*this*/); // downloader
				        dispatcher_.dispatchEvent(streamingEvent);    
                    }
                }
            }
            
            var upstreamPeers:Vector.<String> = getUpstreamPeers();
            JavascriptCall.set_upstream_peers(upstreamPeers);
        }
        
        public function get session():RtmfpSession {
            return session_;
        }
        
        public function get chunkCache():ChunkCache {
            return chunkCache_;
        }
        
        private function onRepaireProcess(event:TimerEvent):void {
            // TODO: do something
            if (needRepaire_ && !blockRepair_) {
                if (repairer_.isRepairTopo || needRepaireUrl_ == null) {
                    // do nothing
                }
                else{
                    var failedPeers:Vector.<Peer> = new Vector.<Peer>();
                    for (var i:int = 0; i < needRepairePeers_.length; i++) {
                        failedPeers.push(needRepairePeers_[i]);
                        needRepaireStates_[i] = 1;
                    }
                    // repaire
                    status_ = RE_SEARCHING_NETWORK;
                    isFakeFailedPeers_ = false;
                    RemoteLogger.log(logPrefix + "repairTopology");
                    repairer_.repairTopology(failedPeers, needRepaireUrl_);
                }
            }
            else {
                // do nothing
            }
            
            repaireTimer_.reset();
            repaireTimer_.start();
        }
        
        public function getUnUsedPeer(count:int = -1):Vector.<Peer> {
            var ret:Vector.<Peer> = new Vector.<Peer>();
            
            for (var k:String in peers_) {
                var peer:Peer = peers_[k];
                
                if (count != -1 && ret.length >= count) {
                    break;
                }
                
                if (!peer.reqStatus.isUsed && peer.msgHooker == null && peer.isReady) {
                    /*
                    var e:P2PNetworkEvent = new P2PNetworkEvent(P2PNetworkEvent.STATUS);
                    e.code = P2PNetworkEvent.DROP_PEER_LISTENER;
                    e.peer = peer;
                    dispatchEvent(e);
                    */
                    
                    /*
                    peer.removeEventListener(PeerStatusEvent.PEER_STATUS, onPeerStatus);
                    peer.removeEventListener(PeerMsgEvent.MSG, onPeerMsg);
                    peer.removeEventListener(PeerMsgErrorEvent.ERROR, onPeerMsgError);
                    */
                    ret.push(peer);        
                }
            }
            
            return ret;
        }
        
        private function ontestTimer(event:TimerEvent):void {

        }
        
        override public function chunkUpdated(chunk:Chunk):void {
            if (chunk.isReady) {
                DebugLogger.log(logPrefix + "chunkUpdated chunk ready");
            }
            
            propagatePushPiece(chunk);
        }
        
        override public function get isOpen():Boolean {
            return isOpen_;
        }
        
        override public function get isComplete():Boolean {
            return isComplete_;
        }
        
        override public function get hasData():Boolean {
            return hasData_;
        }
        
        override public function get hasErrors():Boolean {
            return hasErrors_;
        }
        
        /**
		 * Returns the duration of the last download in seconds.
		 */
        override public function get downloadDuration():Number {
            return downloadDuration_;
        }
        
        override public function get downloadBytesCount():Number {
            return downloadBytesCount_;
        }
        
        override public function get totalAvailableBytes():int {
            return savedData_.bytesAvailable;
        }
        
        override public function clearSavedBytes():void {
            if(savedData_ == null)
			{
				// called after dispose
				return;
			}
			savedData_.length = 0;
			savedData_.position = 0;
        }
        
        override public function appendToSavedBytes(source:IDataInput, count:uint):void {
			if(savedData_ == null)
			{
				// called after dispose
				return;
			}
			source.readBytes(savedData_, savedData_.length, count);
        }
        
        override public function saveRemainingBytes():void {
            // Do nothing now
        }
        
        override public function changeToP2P(uri:String):void {
            isFakeFailedPeers_ = true;
            needRepaire_ = false;
            blockRepair_ = false;
            
            var failedPeers:Vector.<Peer> = new Vector.<Peer>();
            
            if (pieceInfos_ == null) {
                setPieceInfo(chunkCache_.getAvgChunkSize(), P2PSetting.CHUNK_PEERS_COUNT);
            }
            
            for (var i:int = 0; i < pieceInfos_.length; i++) {
                var peer:Peer = new Peer();
                peer.reqStatus.pushChunkOffset = pieceInfos_[i]['offset'];
                peer.reqStatus.pushChunkLen = pieceInfos_[i]['len'];
                peer.reqStatus.pushPieceID = pieceInfos_[i]['id'];
                
                failedPeers.push(peer);
            }
            
            repairer_.repairTopology(failedPeers, uri, true);
        }
        
        override public function findPeers(uri:String):void {
            DebugLogger.log(logPrefix + "findPeers");
            findPeers_ = true;
            status_ = SEARCHING_NETWORK;
            currentChunk_ = new Chunk(uri);
            currentChunk_.pieceCount = qualifiedPeerCount_;
            currentChunkPeers_ = 0;
            currentDetermined_ = false;
            chunkCache_.addChunk(currentChunk_);
            
            setStatusForHasChunkReq();
            
            var hasPeer:Boolean = false;
            for (var k:String in peers_) {
                hasPeer = true;
                var peer:Peer = peers_[k];
                
                if (peer.isReady) {
                    peer.reqHasChunk(currentChunk_.uri);
                }
                else {
                    hasPendingReq_ = true;
                    peer.pendingReq = peer.buildReqHasChunk(currentChunk_.uri);
                }
            }
            
            if (!hasPeer && !getPeersErrorEventIssued_) {
                getPeersErrorEventIssued_ = true;
                var e:P2PNetworkEvent = new P2PNetworkEvent(P2PNetworkEvent.STATUS);
                e.code = P2PNetworkEvent.GET_PEERS_ERROR;
                dispatchEvent(e);
            }
        }
        
        private function startMonitorGetChunk(timeout:int):void {
            if (getChunkTimer_ == null) {
                getChunkTimer_ = new Timer(timeout, 1);
                getChunkTimer_.addEventListener(TimerEvent.TIMER_COMPLETE, onGetChunkTimeout);
                getChunkTimer_.start();
            }
            else{
                getChunkTimer_.delay = timeout;
                getChunkTimer_.reset();
                getChunkTimer_.start();
            }
        }
        
        override public function getChunk(uri:String, dispatcher:IEventDispatcher, timeout:int):void {
            lastTimeout_ = timeout;
            dispatcher_ = dispatcher;
            
            stopMonitorGetChunk();
            
            DebugLogger.log(logPrefix + toString());
            
            if (needRepaire_ && !blockRepair_) {
                repairer_.repairData(uri, lastTimeout_);
            }
            
            if (!isPullMode_) {
                if (appendPushDataTimer_ == null) {
                    appendPushDataTimer_ = new Timer(60, 0);
                    appendPushDataTimer_.addEventListener(TimerEvent.TIMER, onAppendPushData);
                    appendPushDataTimer_.start();
                }
                else {
                    appendPushDataTimer_.reset();
                    appendPushDataTimer_.start();
                }
                lastReqUri_ = uri;
                startMonitorGetChunk(timeout);
                return;    
            }
            
            startMonitorGetChunk(P2PSetting.GET_CHUNK_FIRST_TIMEOUT);
            
            var chunk:Chunk = chunkCache_.findChunk(uri);
            
            DebugLogger.log(logPrefix + "getChunk " + uri);
            
            if (!chunk) {
                // TODO: in push mode, we will wait
                throw new ArgumentError("no chunk found for " + uri);
            }
            
            lastReq_ = chunk;
            lastReqUri_ = lastReq_.uri;
            chunk.state = ChunkState.LOADING_FROM_PEERS;
            
            var usedCount:int = getUsedPeerCount();
            if (usedCount < chunk.pieceCount) {
                var e:P2PNetworkEvent = new P2PNetworkEvent(P2PNetworkEvent.STATUS);
                DebugLogger.log(logPrefix + "no enough peers");
                e.code = P2PNetworkEvent.GET_CHUNK_ERROR;
                dispatchEvent(e);
                return;
            }
            
            piecesWritten_ = new Vector.<Boolean>();
            pieceNextWrittenIdx_ = 0;
            
            var pi:int = 0;
            for (var k:String in peers_) {
                var peer:Peer = peers_[k];
                var ps:PeerReqStatus = peer.reqStatus;
                if (ps.isUsed) {
                    if (pi >= chunk.pieces.length) {
                        throw new Error("pi >= chunk.pieces.length");
                    }
                    
                    peer.reqStatus.setChunkInfo(chunk.pieces[pi].pieceID, chunk.pieceCount, chunk.upstreamChunkAvgSize);
                    peer.reqGetPiece(chunk.uri, chunk.pieces[pi].pieceID, chunk.pieceCount, peer.reqStatus.pushChunkOffset,
                                peer.reqStatus.pushChunkLen);
                    DebugLogger.log(logPrefix + "reqGetPiece, pieceID=" + chunk.pieces[pi].pieceID 
                                + " pieceCount=" + chunk.pieceCount + " offset=" + peer.reqStatus.pushChunkOffset
                                + " len=" + peer.reqStatus.pushChunkLen
                                );
                    piecesWritten_.push(false);
                    pi++;
                }
            }
            
            if (pieceInfos_ == null) {
                setPieceInfo(chunk.upstreamChunkAvgSize, chunk.pieceCount);
            }
            
            getPieceStartTime_ = getTimer();
            
            isOpen_ = true;
        }
        
        private function getStartIndex(chunk:Chunk):int {
            if (lastAppendPos_ == 0) {
                return 0;
            }
            else {
                var curPos:int = 0;
                for (var i:int = 0; i < chunk.pieces.length; i++) {
                    var piece:Piece = chunk.pieces[i];
                    
                    curPos += piece.content.length;
                    
                    if (curPos == lastAppendPos_) {
                        return i+1;
                    }                  
                }
                
                throw new Error("bad state");
            }
        }
        
        private function onAppendPushData(event:TimerEvent):void {
            isOpen_ = true;
            var chunk:Chunk = chunkCache_.findChunk(lastReqUri_);
            
            if (chunk == null) {
                return;
            }
            
            /* DEBUG
            if (chunk.pieces.length == 2) {
                DebugLogger.log(session_.sessionID + " DefaultP2PNetwork dump chunk uri=" + chunk.uri
                    + " chunk size=" + chunk.size + " isReady=" + chunk.isReady);
                for (var j:int; j < chunk.pieces.length; j++) {
                    var p:Piece = chunk.pieces[j];
                    DebugLogger.log(session_.sessionID + " DefaultP2PNetwork isReady=" + p.isReady
                        + " piece.chunkOffset=" + p.chunkOffset + " lastAppendPos_=" + lastAppendPos_ + 
                        " len=" + p.content.length);
                }
            }
            */
            
            for (var i:int = getStartIndex(chunk); i < chunk.pieces.length; i++) {
                var piece:Piece = chunk.pieces[i];
                
                if (piece.isReady && piece.chunkOffset == lastAppendPos_ && piece.content) {
                    DebugLogger.log(logPrefix + "append data, piece len=" + piece.content.length
                    + " chunk size=" + chunk.size + " pieces size=" + chunk.pieces.length 
                    + " chunkOffset=" + piece.chunkOffset + " uri=" + chunk.uri);
                    piece.content.readBytes(savedData_, savedData_.length, piece.content.length);
                    piece.content.position = 0;
                    
                    var streamingEvent:HTTPStreamingEvent = new HTTPStreamingEvent(
                        HTTPStreamingEvent.DOWNLOAD_PROGRESS,
                        false, // bubbles
                        false, // cancelable
                        0, // fragment duration
                        null, // scriptDataObject
                        FLVTagScriptDataMode.NORMAL, // scriptDataMode
                        lastReqUri_, // urlString
                        0, // bytesDownloaded
                        HTTPStreamingEventReason.NORMAL, // reason
                        null /*this*/); // downloader
                    dispatcher_.dispatchEvent(streamingEvent);
                    
                    lastAppendPos_ = lastAppendPos_ + piece.content.length;
                }
                else {
                    break;
                }
            }
            
            //DebugLogger.log(session_.sessionID + " DefaultP2PNetwork lastAppendPos_=" + lastAppendPos_
            //      + " chunk.size=" + chunk.size);
            if (lastAppendPos_ == chunk.size) {
                isComplete_ = true;
                var completeEvent:HTTPStreamingEvent = new HTTPStreamingEvent(
                    HTTPStreamingEvent.DOWNLOAD_COMPLETE,
                    false, // bubbles
                    false, // cancelable
                    0, // fragment duration
                    null, // scriptDataObject
                    FLVTagScriptDataMode.NORMAL, // scriptDataMode
                    lastReqUri_, // urlString
                    downloadBytesCount_, // bytesDownloaded
                    HTTPStreamingEventReason.NORMAL, // reason
                    null /*this*/); // downloader
                dispatcher_.dispatchEvent(completeEvent);
                
                stopMonitorGetChunk();
                
                if (chunk.state == ChunkState.LOADING_FROM_PEERS) {
                    chunk.state = ChunkState.LOAD_FROM_PEERS_DONE;
                }
                
                DebugLogger.log(logPrefix + "OK for url:" + lastReqUri_);             
                appendPushDataTimer_.stop();
            }
        }
        
        private function stopMonitorGetChunk():void {
            if(getChunkTimer_){
                getChunkTimer_.stop();
            }
        }
        
        override public function getBytes(numBytes:int = 0):IDataInput {
            if (numBytes < 0) {
                return null;
            }
            
            if (numBytes == 0) {
                numBytes = 1;
            }
            
            if (savedData_.bytesAvailable < numBytes) {
                return null;
            }
            
            return savedData_;
        }
        
        override public function close(dispose:Boolean = false):void {
            lastReq_ = null;
            lastReqPieceID = -2;
            savedData_ = new ByteArray();
            piecesWritten_ = null;
            pieceNextWrittenIdx_ = 0;
            dispatcher_ = null;
            isComplete_ = false;
            isOpen_ = false;
            hasErrors_ = false;
            
            getchunkTimeoutCount_ = 0;
            
            if (appendPushDataTimer_) {
                appendPushDataTimer_.stop();
            }
            lastAppendPos_ = 0;
            
            stopMonitorGetChunk();
            // TODO: cancle ongoing request
            
            if (dispose) {
                setStatisticsTimer_.stop();
                setStatisticsTimer_.removeEventListener(TimerEvent.TIMER, onSetStatistics);
            }
        }
        
        private function sendPingToUnPushedPeer():void {
            var chunk:Chunk = chunkCache_.findChunk(lastReqUri_);
            
            // clear
            needRespPingIds_.splice(0, needRespPingIds_.length);
            needRespSpeedTestIds_.splice(0, needRespSpeedTestIds_.length);
            
            for (var k:String in peers_) {
                var peer:Peer = peers_[k];
                
                if (peer.reqStatus.pushPieceID != -1) {
                    if (!chunk || !chunk.isPieceReady(peer.reqStatus.pushPieceID)) {
                        // PING
                        needRespPingIds_.push(peer.id);
                        peer.reqPing();
                    }
                }
            }
        }
        
        private function getSlowPeers():Vector.<Peer> {
            var slowPeers:Vector.<Peer> = new Vector.<Peer>();
            for (var i:int = 0; i < needRespSpeedTestIds_.length; i++) {
                var peer:Peer = peers_[needRespSpeedTestIds_[i]];
                
                if (peer.reqStatus.lastPushPieceUsedTime >= P2PSetting.MAX_TRANSFER_TIME_FOR_PIECE) {
                    slowPeers.push(peer);
                }
            }
            
            return slowPeers;
        }
        
        private function handleGetChunkTimeoutStage2():void {
            var needFixPeers:Vector.<Peer> = new Vector.<Peer>();
            for (var j:int = 0; j < needRespPingIds_.length; j++) {
                needFixPeers.push(peers_[needRespPingIds_[j]]);
            }
            
            needFixPeers = needFixPeers.concat(getSlowPeers());
            
            if (needFixPeers.length == 0) {
                if (checkAndRemoveErrorUri(lastReqUri_))
                {
                    repairer_.repairData(lastReqUri_, lastTimeout_);
                }
                else{
                    for (var i:int = 0; i < needRespSpeedTestIds_.length; i++) {
                        var peer:Peer = peers_[needRespSpeedTestIds_[i]];
                        lastSpeedTestId_ = "DefaultP2PNetwork" + speedTestId_;
                        peer.speedTestResult = -1;
                        DebugLogger.log(logPrefix + "speed test for peer.id=" + peer.id);
                        peer.reqSpeedTest(lastSpeedTestId_);
                    }
                    speedTestId_++;
                    startMonitorGetChunk(lastTimeout_);
                }
                
                return;
            }
            
            status_ = RE_SEARCHING_NETWORK;

            DebugLogger.log(logPrefix + "wait ping timeout");
            
            // PING ERROR, either die or jammed
            for (j = 0; j < needFixPeers.length; j++) {
                var p:Peer = needFixPeers[j];
                addPeerToFailedList(p);
                if (!isInRepaireList(p)) {
                    needRepairePeers_.push(p);
                    needRepaireStates_.push(0);
                }
            }
            
            for (i = 0; i < needFixPeers.length; i++) {
                peer = needFixPeers[i];
                peer.close();
            }
            
            needFixPeers.splice(0, needFixPeers.length);
           
            setAllPaused();
            
            needRepaire_ = true;
            needRepaireUrl_ = lastReqUri_;
            repairer_.repairData(lastReqUri_, lastTimeout_);
        }
        
        private function setAllPaused():void {
            for (var k:String in peers_) {
                var ps:Peer = peers_[k];
                
                if (ps.reqStatus.isUsed && ps.reqStatus.mode == PeerStatus.PUSH_MODE) {
                    ps.reqPausePush();
                    ps.reqStatus.mode = PeerStatus.PUSH_MODE_PAUSED;
                }
            }
        }
        
        private function handleGetChunkTimeoutStage3():void {
            var timeoutPeers:Vector.<Peer> = new Vector.<Peer>();
            for (var i:int = 0; i < needRespSpeedTestIds_.length; i++) {
                var peerId:String = needRespSpeedTestIds_[i];
                var peer:Peer = peers_[peerId];
                
                var testFailed:Boolean = false;
                if (peer.speedTestResult == -1) {
                    DebugLogger.log(logPrefix + "speed test timeout for peer: " + peer.id);
                    addPeerToFailedList(peer);
                    testFailed = true;
                }
                else {
                    if (peer.speedTestResult > 3000) {
                        testFailed = true;
                    }
                    DebugLogger.log(logPrefix + "speed test result " + peer.speedTestResult + 
                                    " for peer: " + peer.id);
                }
                
                if (testFailed) {
                    addPeerToFailedList(peer);
                    if (!isInRepaireList(peer)) {
                        needRepairePeers_.push(peer);
                        needRepaireStates_.push(0);
                    }
                }
            }
            
            if(needRepairePeers_.length > 0){
                // TODO: do something
                needRepaire_ = true;
                needRepaireUrl_ = lastReqUri_;
                repairer_.repairData(lastReqUri_, lastTimeout_);
            }
            else {
                if (checkAndRemoveErrorUri(lastReqUri_))
                {
                    repairer_.repairData(lastReqUri_, lastTimeout_);
                }
                else{
                    startMonitorGetChunk(P2PSetting.DESPERATE_TIMEOUT);
                }
            }
        }
        
        private function checkAndRemoveErrorUri(uri:String):Boolean {
            if (pushPieceErrorUris.length == 0) {
                // NO ERROR
                return false;
            }
            
            var uri1:URL = new URL(uri);
                            
            for (var i:int = 0; i < pushPieceErrorUris.length; i++) {
                var uri2:URL = new URL(pushPieceErrorUris[i]);
                
                if (uri1.path == uri2.path) {
                    pushPieceErrorUris.splice(i, 1);
                    return true;
                }
            }
            
            return false;
        }
        
        private function onGetChunkTimeout(event:TimerEvent):void {
            getchunkTimeoutCount_++;
            if (getchunkTimeoutCount_ == 1) {
                if (!isPullMode_) {
                    if (needRepaire_) {
                        repairer_.repairData(lastReqUri_, lastTimeout_);
                        needRepaireUrl_ = lastReqUri_;
                    }
                    else {
                        if (checkAndRemoveErrorUri(lastReqUri_)) {
                            repairer_.repairData(lastReqUri_, lastTimeout_);
                        }
                        else{
                            sendPingToUnPushedPeer();
                            startMonitorGetChunk(lastTimeout_);
                        }
                    }
                }
                else {
                    DebugLogger.log(logPrefix + "timeout when in pull mode");
                    appendPushDataTimer_ = new Timer(60, 0);
                    appendPushDataTimer_.addEventListener(TimerEvent.TIMER, onAppendPushData);
                    appendPushDataTimer_.start();
                    
                    needRepaire_ = true;
                    needRepaireUrl_ = lastReqUri_;
                    currentChunk_.removeNullPiece();
                    isPullMode_ = false;
                    canHandleGetPieceResp_ = false;
                    setAllPaused();
                    repairer_.repairData(lastReqUri_, lastTimeout_);
                    
                    for (var k:String in peers_) {
                        var peer:Peer = peers_[k];
                        if (peer.reqStatus.isUsed && !peer.getPieceRespReceived) {
                            if (!isInRepaireList(peer)) {
                                needRepairePeers_.push(peer);
                                needRepaireStates_.push(0);
                            }
                        }
                    }
                }
            }
            else if (getchunkTimeoutCount_ == 2) {
                // check pings
                handleGetChunkTimeoutStage2();
            }
            else if (getchunkTimeoutCount_ == 3) {
                handleGetChunkTimeoutStage3();
            }
            else {
                /*
                hasErrors_ = true;
                
                DebugLogger.log(logPrefix + "onGetChunkTimeout");
                RemoteLogger.log(logPrefix + "onGetChunkTimeout");
                
                // TODO: maybe it will cause screen mess or some other bad thing
                // player may already has got some data of the chunk.
                // should we just repair it?
                
                var streamingEvent:HTTPStreamingEvent = new HTTPStreamingEvent(
                    HTTPStreamingEvent.DOWNLOAD_ERROR,
                    false, // bubbles
                    false, // cancelable
                    0, // fragment duration
                    null, // scriptDataObject
                    FLVTagScriptDataMode.NORMAL, // scriptDataMode
                    lastReqUri_, // urlString
                    0, // bytesDownloaded
                    HTTPStreamingEventReason.TIMEOUT, // reason
                    null); // downloader
                dispatcher_.dispatchEvent(streamingEvent);
                */
                
                RemoteLogger.log(logPrefix + "onGetChunkTimeout");
                
                var chunk:Chunk = chunkCache_.findChunk(lastReqUri_);
                // if we do not have the chunk or if the chunk is not ready
                if (!chunk || !chunk.isReady) {
                    repairer_.repairData(lastReqUri_, lastTimeout_);
                }
            }
        }
        
        public function get status():String {
            return status_;
        }
        
        private function getUsedPeerCount():int {
            var ret:int = 0;
            for (var k:String in peers_) {
                var peer:Peer = peers_[k];
                var ps:PeerReqStatus = peer.reqStatus;
                if (ps.isUsed) {
                    ret++;
                }
            }
            
            return ret;
        }
        
        // session events handler
        
        private function onSessionAsyncError(event:AsyncErrorEvent):void {
            DebugLogger.log(logPrefix + "onSessionAsyncError");
        }
        
        private function onSessionIOError(event:IOErrorEvent):void {
            DebugLogger.log(logPrefix + "onSessionIOError");
        }
        
        private function onSessionNetStatus(event:NetStatusEvent):void {
            DebugLogger.log(logPrefix + "onSessionNetStatus, code: " + event.info.code);
            switch(event.info.code) {
                case "NetStream.Connect.Closed":
                    DebugLogger.log(logPrefix + "closed peer id=" + event.info.stream.farID);
                    onPeerClose(event.info.stream.farID);
                    break;
                case "NetConnection.Connect.Closed":
                    break;
                default:
                    break;
            }
        }
        
        private function isInRepaireList(peer:Peer):Boolean {
            for (var i:int = 0; i < needRepairePeers_.length; i++) {
                if (needRepairePeers_[i].id == peer.id) {
                    return true;
                }
            }
            
            return false;
        }
        
        private function onPeerClose(peerID:String):void {
            // this may be called for several times
            if (!peers_[peerID]) {
                return;
            }
            
            var peer:Peer = peers_[peerID];
            peer.close();
            
            handleDeletePeer(peer);
            
            DebugLogger.log(logPrefix + "onPeerClose: delete " + peerID);
            delete peers_[peerID];
            
            var downstreamPeers:Vector.<String> = getDownstreamPeers();
            JavascriptCall.set_downstream_peers(downstreamPeers);
            
            if (findPeers_ && !currentDetermined_) {
                determinIfEnoughPeers();
            }
            DebugLogger.log(logPrefix + "onPeerClose, peer count: " + DictionaryUtil.len(peers_));
        }
        
        private function handleDeletePeer(peer:Peer):void {
            if (!isFailedPeer(peer.id) && !peer.normalClose) {
                DebugLogger.log(logPrefix + "addPeerToFailedList, peer.id="
                    + peer.id + " peer.normalClose=" + peer.normalClose);
                addPeerToFailedList(peer);
            }
            
            if (peer.reqStatus.isUsed && (peer.reqStatus.mode != PeerStatus.PULL_MODE) && !isInRepaireList(peer)) {
                needRepaireUrl_ = null;
                needRepaire_ = true;
                
                needRepairePeers_.push(peer);
                needRepaireStates_.push(0);
            }
        }
        
        private function onSessionSecurityError(event:SecurityErrorEvent):void {
            DebugLogger.log(logPrefix + "onSessionSecurityError");
        }
        
        // end of session events handler
        
        private function onPublishPointHasPeer(event:PublishPointEvent):void {
            if (peers_[event.peerID]) {
                peers_[event.peerID].localPubPPConnected = true;
                return;
            }
            
            createPeer(event.peerID, true);
        }
        
        private function onPeerMsgError(event:PeerMsgErrorEvent):void {
            var peer:Peer = event.peer;
            var msg:PeerMsg = event.msg;
            
            onPeerClose(peer.id);
            
            DebugLogger.log(logPrefix + "onPeerMsgError");
            
            if (msg.hasMsgSubType && (msg.msgSubType == PeerMsg.SUB_TYPE_HAS_CHUNK)) {
                peer.reqStatus.hasChunkFinished = true;
                
                if (findPeers_ && !currentDetermined_) {
                    determinIfEnoughPeers();
                }
            }
        }
        
        private function onPeerMsg(event:PeerMsgEvent):void {
            event.peer.statistics.inBytes += event.msg.getMsgSize();
            
            // TODO: send to hook subsystem
            if (event.peer.msgHooker) {
                if (event.peer.msgHooker.hook(event)) {
                    return;
                }
            }
            
            if (event.msg.msgType == PeerMsg.REQ) {
                switch(event.msg.msgSubType)
                {
                    case PeerMsg.SUB_TYPE_HAS_CHUNK:
                        handleHasChunkReq(event);
                        break;
                    case PeerMsg.SUB_TYPE_PAUSE_PUSH:
                        handlePausePushReq(event);
                        break;
                    case PeerMsg.SUB_TYPE_STOP_PUSH:
                        handleStopPushReq(event);
                        break;
                    case PeerMsg.SUB_TYPE_RESUME_PUSH:
                        handleResumePushReq(event);
                        break;
                    case PeerMsg.SUB_TYPE_GET_PIECE:
                        handleGetPieceReq(event);
                        break;
                    case PeerMsg.SUB_TYPE_GO_PUSH_MODE:
                        handleGoPushReq(event);
                        break;
                    case PeerMsg.SUB_TYPE_GO_PUSH_MODE2:
                        handleGoPushReq2(event);
                        break;
                    case PeerMsg.SUB_TYPE_PING:
                        handlePingReq(event);
                        break;
                    case PeerMsg.SUB_TYPE_SPEED_TEST:
                        handleSpeedTestReq(event);
                        break;
                    case PeerMsg.SUB_TYPE_CLOSE:
                        handleCloseReq(event);
                    default:
                        break;
                }
            }
            else if(event.msg.msgType == PeerMsg.RESP)
            {
                switch(event.msg.msgSubType) {
                    case PeerMsg.SUB_TYPE_HAS_CHUNK:
                        handleHasChunkResp(event);
                        break;
                    case PeerMsg.SUB_TYPE_GET_PIECE:
                        handleGetPieceResp(event);
                        break;
                    case PeerMsg.SUB_TYPE_GO_PUSH_MODE:
                        handleGoPushResp(event);
                        break;
                    case PeerMsg.SUB_TYPE_PUSH_PIECE:
                        handlePushPiece(event);
                        break;
                    case PeerMsg.SUB_TYPE_PUSH_PIECE_ERROR:
                        handlePushPieceError(event);
                        break;
                    case PeerMsg.SUB_TYPE_PING:
                        handlePingResp(event);
                        break;
                    case PeerMsg.SUB_TYPE_SPEED_TEST:
                        handleSpeedTestResp(event);
                        break;
                    default:
                        break;
                }
            }
            else { // RESP_CONFIRM
                switch(event.msg.msgSubType) {
                    case PeerMsg.SUB_TYPE_GO_PUSH_MODE:
                        handleGoPushRespConfirm(event);
                        break;
                }
            }
        }
        
        private function handlePausePushReq(event:PeerMsgEvent):void {
            var peer:Peer = event.peer;
            
            //if (peer.respStatus.mode == PeerStatus.PUSH_MODE) {
            peer.respStatus.mode = PeerStatus.PUSH_MODE_PAUSED;
            //}
        }
        
        private function handleStopPushReq(event:PeerMsgEvent):void {
            var peer:Peer = event.peer;
            
            peer.respStatus.mode = PeerStatus.PULL_MODE;
            
            peer.respStopPush(event.msg);
        }
        
        public function getPeerCountByGroup():Object {
            var ret:Object = new Object();
            ret["in"] = 0;
            ret["out"] = 0;
            ret["none"] = 0;
            ret["all"] = 0;
            
            for (var i:String in peers_) {
                ret['all'] += 1;
                var peer:Peer = peers_[i];
                if (!peer.reqStatus.canBeRemoved) {
                    ret["in"] += 1;
                }
                
                if (!peer.respStatus.canBeRemoved) {
                    ret["out"] += 1;
                }
                
                if (peer.canBeRemoved) {
                    ret["none"] += 1;
                }
            }
            
            return ret;
        }
        
        private function handleResumePushReq(event:PeerMsgEvent):void {
            var uri:String = event.msg.obj["uri"];
            var peer:Peer = event.peer;
            
            peer.respStatus.mode = PeerStatus.PUSH_MODE_RESUME;
            peer.respStatus.pushResumeUri = uri;
            
            var resumeChunk:Chunk = chunkCache_.findChunk(peer.respStatus.pushResumeUri);
            if (resumeChunk == null) {
                // the chunk is not ready
                return;
            }
            else {
                peer.respStatus.mode = PeerStatus.PUSH_MODE;
                // in case, though here goPushIdx should not be -1
                if((peer.respStatus.goPushIdx == -1) || (resumeChunk.idx > peer.respStatus.goPushIdx)){
                    peer.respStatus.goPushIdx = resumeChunk.idx;
                }
                
                var lastPushChunks:Vector.<Chunk> = chunkCache_.getChunksNewerByIdx(peer.respStatus.goPushIdx);
                pushCurrentChunks(lastPushChunks, peer);
            }
        }
        
        private function handleSpeedTestResp(event:PeerMsgEvent):void {
            var peer:Peer = event.peer;
            var msg:PeerMsg = event.msg;
            
            if (msg.obj["id"] == lastSpeedTestId_) {
                peer.speedTestResult = (new Date()).getTime() - msg.obj["start_time"].getTime();
            }
            
            DebugLogger.log(logPrefix + "handleSpeedTestResp peer.id=" + peer.id + " peer.speedTestResult="
                        + peer.speedTestResult);
        }
        
        private function handleSpeedTestReq(event:PeerMsgEvent):void {
            DebugLogger.log(logPrefix + "handleSpeedTestReq");
            var peer:Peer = event.peer;
            var msg:PeerMsg = event.msg;
            
            peer.respSpeedTest(msg);
        }
        
        private function handleCloseReq(event:PeerMsgEvent):void {
            DebugLogger.log(logPrefix + "peer.id=" + event.peer.id);
            event.peer.normalClose = true;
            onPeerClose(event.peer.id);
        }
        
        private function writeAvailablePieces(chunk:Chunk):void {
            for (var i:int = pieceNextWrittenIdx_; i < piecesWritten_.length; i++) {
                if (!piecesWritten_[i]) {
                    if (i != pieceNextWrittenIdx_) {
                        break;
                    }
                    if (chunk.pieces[i].isReady) {
                        chunk.pieces[i].content.readBytes(savedData_, savedData_.length);
                        chunk.pieces[i].content.position = 0;
                        piecesWritten_[i] = true;
                        pieceNextWrittenIdx_++;
                        
                        DebugLogger.log(logPrefix + "read piece: "
                                        + chunk.pieces[i].pieceID
                                        );
                        
                        // dispatch progress event
                        if(dispatcher_ != null)
                        {
                            var streamingEvent:HTTPStreamingEvent = new HTTPStreamingEvent(
                                HTTPStreamingEvent.DOWNLOAD_PROGRESS,
                                false, // bubbles
                                false, // cancelable
                                0, // fragment duration
                                null, // scriptDataObject
                                FLVTagScriptDataMode.NORMAL, // scriptDataMode
                                lastReq_.uri, // urlString
                                0, // bytesDownloaded
                                HTTPStreamingEventReason.NORMAL, // reason
                                null /*this*/); // downloader
                            dispatcher_.dispatchEvent(streamingEvent);
                        }
                    }
                    else {
                        break;
                    }
                }
            }
        }
        
        private function handlePushPieceError(event:PeerMsgEvent):void {
            var chunk:Chunk = chunkCache_.findChunk(event.msg.obj["uri"]);
            
            // if we do not have that chunk or that chunk is ready.
            if (chunk == null || !chunk.isReady)
            {
                pushPieceErrorUris.push(event.msg.obj["uri"]);
            }
            
            var e:P2PNetworkEvent = new P2PNetworkEvent(P2PNetworkEvent.STATUS);
            e.code = P2PNetworkEvent.IDX_NOT_READY;
            dispatchEvent(e);
        }
        
        private function handlePushPiece(event:PeerMsgEvent):void {
            var msg:PeerMsg = event.msg;
            DebugLogger.log(logPrefix + "handlePushPiece, " +
                "uri=" + msg.obj["uri"] +
                " lastUsedTime=" + event.msg.obj['lastUsedTime'] + " lastSize=" + event.msg.obj['lastSize']
                + " timeInQueue=" + (event.msg.sendTimestamp.getTime() - event.msg.queueTimestamp.getTime())
                + " from=" + event.peer.id + " isFromStableSource=" + msg.obj["isFromStableSource"]
                + " chunkSize=" + msg.obj["chunkSize"] + " id=" + msg.obj["id"]
                + " offset=" + msg.obj['offset'] + ' length=' + msg.obj['data'].length);
            var chunk:Chunk = chunkCache_.findChunk(msg.obj["uri"]);
            
            event.peer.reqStatus.lastPushPieceUsedTime = event.msg.obj['lastUsedTime'];
            
            if (chunk == null) {
                chunk = new Chunk(msg.obj["uri"]);
                chunk.state = ChunkState.LOADING_FROM_PEERS;
                chunk.isFromStableSource = msg.obj["isFromStableSource"];
                chunkCache_.addChunk(chunk);
            }
            else {
                if (chunk.state != ChunkState.LOADING_FROM_PEERS) {
                    return;
                }
                
                chunk.isFromStableSource = msg.obj["isFromStableSource"];
            }
            
            if(msg.obj["chunkSize"] != -1) {
                chunk.size = msg.obj["chunkSize"];
            }
            
            chunkCache_.indexData = msg.obj["idxData"];
            if (msg.obj["idxData"] != null) {
                var e:P2PNetworkEvent = new P2PNetworkEvent(P2PNetworkEvent.STATUS);
                e.code = P2PNetworkEvent.IDX_READY;
                dispatchEvent(e);
            }
            
            var piece:Piece = new Piece(msg.obj["id"]);
            // set piece property
            piece.content = msg.obj['data'];
            piece.chunkOffset = msg.obj['offset'];
            piece.contentLength = piece.content.length;
            piece.isReady = true;
            
            //var oldPieceSize:int = chunk.pieces.length;
            
            var pieceAdded:Boolean = false;
            // for empty content, we only need to update chunk.size
            if(piece.content.length > 0){
                pieceAdded = chunk.addPiece(piece);
            }
            
            /*
            var newPieceSize:int = chunk.pieces.length;
            
            DebugLogger.log(session_.sessionID + " DefaultP2PNetwork oldPieceSize=" + oldPieceSize
                            + " newPieceSize=" + newPieceSize + " uri=" + chunk.uri);
            */
            
            if(pieceAdded){
                DebugLogger.log(logPrefix + "offset=" + piece.chunkOffset 
                    + " len=" + piece.content.length
                    + " chunk.size=" + chunk.size
                    + " from=" + event.peer.id
                    + " url=" + chunk.uri);
            
                propagatePushPiece(chunk);
            }
        }
        
        private function handlePingResp(event:PeerMsgEvent):void {
            DebugLogger.log(logPrefix + "handlePingResp");
            var peer:Peer = event.peer;
            var msg:PeerMsg = event.msg;
            
            if (msg.obj["pingId"] == peer.reqStatus.lastPingId) {
                peer.reqStatus.lastPingId++;
                
                for (var i:int = 0; i < needRespPingIds_.length; i++) {
                    if (needRespPingIds_[i] == peer.id) {
                        needRespPingIds_.splice(i, 1);
                        needRespSpeedTestIds_.push(peer.id);
                        break;
                    }
                }
            }
        }
        
        private function propagatePushPiece(chunk:Chunk):void {
            //DebugLogger.log(session_.sessionID + " DefaultP2PNetwork: propagatePushPiece " + chunk.uri);
            for (var k:String in peers_) {
                var peer:Peer = peers_[k];
                //DebugLogger.log(session_.sessionID + " DefaultP2PNetwork: mode=" + peer.respStatus.mode);
                if (peer.respStatus.mode != PeerStatus.PUSH_MODE && peer.respStatus.mode != PeerStatus.PUSH_MODE_RESUME) {
                    continue;
                }
                
                if (peer.respStatus.mode == PeerStatus.PUSH_MODE_RESUME) {
                    var resumeChunk:Chunk = chunkCache_.findChunk(peer.respStatus.pushResumeUri);
                    if (resumeChunk == null) {
                        // the chunk is not ready
                        return;
                    }
                    else {
                        peer.respStatus.mode = PeerStatus.PUSH_MODE;
                        if((peer.respStatus.goPushIdx == -1) || (resumeChunk.idx > peer.respStatus.goPushIdx)){
                            peer.respStatus.goPushIdx = resumeChunk.idx;
                        }
                        peer.respStatus.pushStateChangeDelayHandled = false;
                    }
                }
                
                /*
                DebugLogger.log(session_.sessionID + " DefaultP2PNetwork goPushChunkOffset=" +
                                peer.respStatus.goPushChunkOffset + " goPushChunkLen=" +
                                peer.respStatus.goPushChunkLen);
                                
                if (chunk.isReady) {
                    DebugLogger.log(session_.sessionID + " DefaultP2PNetwork: ready for " + chunk.uri);
                }
                */
                
                if (chunk.isReady) {
                    DebugLogger.log(logPrefix + "goPushChunkOffset=" + peer.respStatus.goPushChunkOffset
                            + " goPushChunkLen=" + peer.respStatus.goPushChunkLen);
                    
                    for (var j:int = 0; j < chunk.pieces.length; j++) {
                        DebugLogger.log(logPrefix + "piece.chunkOffset=" + chunk.pieces[j].chunkOffset 
                            + " len=" + chunk.pieces[j].content.length);
                    }
                }
                   
                DebugLogger.log(logPrefix + chunk.idx + 
                        " chunk uri=" + chunk.uri +
                        " goPushIdx=" + peer.respStatus.goPushIdx +
                        " peer.id=" + peer.idDesc);
                DebugLogger.log(logPrefix + "goPushChunkOffset=" + peer.respStatus.goPushChunkOffset
                        + " goPushChunkLen=" + peer.respStatus.goPushChunkLen);
                        
                if (!peer.respStatus.pushStateChangeDelayHandled &&
                    (chunk.idx != (peer.respStatus.goPushIdx + 1))
                    ) 
                {
                    var lastPushChunks:Vector.<Chunk> = chunkCache_.getChunksNewerByIdx(peer.respStatus.goPushIdx);
                    pushCurrentChunks(lastPushChunks, peer);
                    //after that chunk.idx may = peer.respStatus.goPushIdx                       
                }
                else {
                    var hasError:Boolean = false;
                    while (true)
                    {
                        var needPushing:Chunk = chunkCache_.findChunkByIdx(peer.respStatus.goPushIdx + 1);
                        if (needPushing != null && needPushing.isError) {
                            peer.pushPieceError(needPushing.uri);
                            peer.respStatus.goPushIdx++; // skip error chunk. TODO: do we need to notify peers
                            hasError = true;
                            RemoteLogger.log(logPrefix + "skip chunk " + peer.respStatus.goPushIdx + " chunk.idx=" + chunk.idx);
                        }
                        else {
                            break;
                        }
                    }
                    
                    if (hasError) {
                        while (true) {
                            var sp:Boolean = sendPendingPushPiece(peer);
                            
                            if (!sp) {
                                break;
                            }
                        }
                    }
                    
                    // in some normal senario: C get chunk from A, B.
                    // A push 1 to C, B do not have 1, push 2 to C, c load 2, will not repair 1
                    // 1 will never be ready.
                    // we check this, and advance idx :::))
                    while (chunk.idx > (peer.respStatus.goPushIdx + 1) && chunk.isReady) {
                        sp = sendPendingPushPiece(peer);
                        
                        // goPushIdx has not been changed
                        if (!sp) {
                            var errorChunk:Chunk = chunkCache_.findChunkByIdx(peer.respStatus.goPushIdx + 1);
                            errorChunk.isError = true;
                            if (errorChunk.getPieceData(peer.respStatus.goPushChunkOffset, peer.respStatus.goPushChunkLen)
                                == null)
                            {
                                peer.pushPieceError(errorChunk.uri);
                            }
                            RemoteLogger.log(logPrefix + "idx=" + chunk.idx + " is READY. skip " + errorChunk.toString());
                            DebugLogger.log(logPrefix + "idx=" + chunk.idx + " is READY. skip " + errorChunk.toString());
                            peer.respStatus.goPushIdx++;
                        }
                    }
                    
                    if (chunk.idx == (peer.respStatus.goPushIdx + 1)) {
                        var piece:ByteArray = chunk.getPieceData(peer.respStatus.goPushChunkOffset, 
                                                peer.respStatus.goPushChunkLen);
                                                             
                        if (piece == null) {
                            continue;
                        }
                        
                        DebugLogger.log(logPrefix + "to peer.id=" + peer.idDesc 
                                            + " piecelen=" + piece.length
                                            + " goPushChunkOffset=" + peer.respStatus.goPushChunkOffset
                                            + " goPushChunkLen=" + peer.respStatus.goPushChunkLen
                                            + " goPushPieceID=" + peer.respStatus.goPushPieceID
                                            + " goPushPieceCount=" + peer.respStatus.goPushPieceCount
                                            + " " + chunk.toString());
                        
                        /*
                        if (chunk.isReady && (peer.respStatus.goPushChunkLen == -1)
                            && (peer.respStatus.goPushChunkOffset + piece.length != chunk.size)) {
                                DebugLogger.log(logPrefix + "[BUG]1 to peer.id=" + peer.idDesc 
                                    + " piecelen=" + piece.length
                                    + " goPushChunkOffset=" + peer.respStatus.goPushChunkOffset
                                    + " goPushChunkLen=" + peer.respStatus.goPushChunkLen
                                    + " goPushPieceID=" + peer.respStatus.goPushPieceID
                                    + " goPushPieceCount=" + peer.respStatus.goPushPieceCount
                                    + " " + chunk.toString());        
                        }
                        
                        if (chunk.isReady && (peer.respStatus.goPushChunkLen != -1)
                            && (piece.length != peer.respStatus.goPushChunkLen) && (piece.length != 0)
                            && (peer.respStatus.goPushChunkOffset + piece.length != chunk.size))
                        {
                                DebugLogger.log(logPrefix + "[BUG]2 to peer.id=" + peer.idDesc 
                                    + " piecelen=" + piece.length
                                    + " goPushChunkOffset=" + peer.respStatus.goPushChunkOffset
                                    + " goPushChunkLen=" + peer.respStatus.goPushChunkLen
                                    + " goPushPieceID=" + peer.respStatus.goPushPieceID
                                    + " goPushPieceCount=" + peer.respStatus.goPushPieceCount
                                    + " " + chunk.toString());     
                        }
                        */
                        
                        //RemoteLogger.log(logPrefix + "to peer.id=" + peer.idDesc + " " + chunk.toString());
                
                        if (piece.length >= 0) {
                            peer.pushPiece(chunk.uri, peer.respStatus.goPushChunkOffset, 
                                        peer.respStatus.goPushPieceID,
                                        piece, chunk.size, chunkCache_.indexData, chunk.isFromStableSource);
                            peer.respStatus.goPushIdx++;
                            
                            while (true) {
                                var ret:Boolean = sendPendingPushPiece(peer);
                                
                                if (!ret) {
                                    break;
                                }
                            }
                        }
                    }
                    else if (chunk.idx > (peer.respStatus.goPushIdx + 1)) {
                        //RemoteLogger.log(logPrefix + "chunk.idx > (peer.respStatus.goPushIdx + 1) happend @.@");
                        piece = chunk.getPieceData(peer.respStatus.goPushChunkOffset, 
                                                peer.respStatus.goPushChunkLen);
                        if (piece.length >= 0) {
                            RemoteLogger.log(logPrefix + "addToPendingPushChunks peer.id=" + peer.idDesc+ " chunk.idx=" + chunk.idx
                            + " goPushIdx=" + peer.respStatus.goPushIdx + " uri=" + chunk.uri
                            );
                            DebugLogger.log(logPrefix + "addToPendingPushChunks peer.id=" + peer.idDesc+ " chunk.idx=" + chunk.idx
                            + " goPushIdx=" + peer.respStatus.goPushIdx + " uri=" + chunk.uri
                            );
                            RemoteLogger.log(logPrefix + " chunk.desp: " + chunkCache_.findChunkByIdx(peer.respStatus.goPushIdx + 1).toString());
                            
                            var supposedChunk:Chunk = chunkCache_.findChunkByIdx(peer.respStatus.goPushIdx + 1);
                            
                            if (supposedChunk == null) {
                                RemoteLogger.log(logPrefix + "goPushIdx=" + supposedChunk.idx + " is NULL");
                                DebugLogger.log(logPrefix + "goPushIdx=" + supposedChunk.idx + " is NULL");
                            }
                            else {
                                var supposedPiece:ByteArray = supposedChunk.getPieceData(peer.respStatus.goPushChunkOffset,
                                            peer.respStatus.goPushChunkLen);
                                
                                if (supposedPiece == null) {
                                    RemoteLogger.log(logPrefix + "supposedPiece is NULL");
                                    DebugLogger.log(logPrefix + "supposedPiece is NULL");
                                }
                            }

                            peer.respStatus.addToPendingPushChunks(chunk);
                        }
                    }
                    
                    peer.respStatus.pushStateChangeDelayHandled = true;
                }
            }
        }
        
        private function sendPendingPushPiece(peer:Peer):Boolean {
            if(peer.respStatus.goPushChunks.length > 0) {
                var chunk:Chunk = peer.respStatus.goPushChunks[0];
                
                if (chunk.idx == (peer.respStatus.goPushIdx + 1)) {
                    var piece:ByteArray = chunk.getPieceData(peer.respStatus.goPushChunkOffset, 
                                                     peer.respStatus.goPushChunkLen);
                                                     
                    peer.pushPiece(chunk.uri, peer.respStatus.goPushChunkOffset, 
                        peer.respStatus.goPushPieceID,
                        piece, chunk.size, chunkCache_.indexData, chunk.isFromStableSource);
                        
                    peer.respStatus.goPushIdx++;
                    
                    peer.respStatus.goPushChunks.shift();
                    
                    return true;
                }
            }
            
            return false;
        }
        
        private function isAllPeerGetPieceRespRet():Boolean {
            for (var k:String in peers_) {
                var peer:Peer = peers_[k];
                if (peer.reqStatus.isUsed && !peer.getPieceRespReceived) {
                    return false;
                }
            }
            
            return true;
        }
        
        private function handleGetPieceResp(event:PeerMsgEvent):void {
            DebugLogger.log(logPrefix + "handleGetPieceResp, peer.id=" + event.peer.id);
            var peer:Peer = event.peer;
            var msg:PeerMsg = event.msg;
            
            if (!canHandleGetPieceResp_) {
                return;
            }
            
            peer.getPieceRespReceived = true;
            if (isAllPeerGetPieceRespRet()) {
                isPullMode_ = false;
            }
            
            DebugLogger.log(logPrefix + "result=" + msg.obj["result"]);
            
            if (!msg.obj["result"]) {
                // do not have the piece, we should re-select
            }
            else {
                var chunk:Chunk = chunkCache_.findChunk(msg.obj["uri"]);
                
                if (chunk == null) {
                    // It may be deleted
                    return;
                }
                
                DebugLogger.log(logPrefix + "chunk.state=" + chunk.state);
                
                if (chunk.state == ChunkState.LOADING_FROM_PEERS) {
                    var piece:Piece = chunk.pieces[msg.obj["id"]];
                    
                    chunk.size = msg.obj["chunkSize"];
                    chunk.isFromStableSource = msg.obj["isFromStableSource"];
                    piece.chunkOffset = msg.obj["chunkOffset"];
                    piece.content = msg.obj["content"];
                    piece.contentLength = piece.content.length;
                    piece.isReady = true;
                    
                    writeAvailablePieces(chunk);
                    
                    peer.reqStatus.mode = PeerStatus.PULL_TO_PUSH;
                    chunkCache_.indexData = msg.obj["idxData"];
                    
                    /*
                    peer.reqStatus.pushPieceID = piece.pieceID;
                    peer.reqStatus.pushPieceCount = chunk.pieceCount;

                    var pieceSize:int = Math.floor(chunk.size / peer.reqStatus.pushPieceCount);
                    peer.reqStatus.pushChunkOffset = pieceSize * peer.reqStatus.pushPieceID;
                    
                    if (pieceInfos_ == null) {
                        setPieceInfo(chunk.size, chunk.pieceCount);
                    }
                    
                    if (peer.reqStatus.pushPieceCount == (peer.reqStatus.pushPieceID + 1)) {
                        // last piece
                        peer.reqStatus.pushChunkLen = -1;
                    }
                    else {
                        peer.reqStatus.pushChunkLen = pieceSize;
                    }
                    */
            
                    // send pull to push mode
                    peer.reqGoPush(chunk.uri, piece.pieceID, chunk.pieceCount, peer.reqStatus.pushChunkOffset,
                        peer.reqStatus.pushChunkLen);
                    DebugLogger.log(logPrefix + "reqGoPush"
                                    + " chunk.uri=" + chunk.uri
                                    + " piece.pieceID=" + piece.pieceID
                                    + " chunk.pieceCount=" + chunk.pieceCount
                                    + " peer.id=" + peer.id);
                                    
                    
                   
                    if (chunk.isReady) {
                        // Dispatch event
                        
                        isComplete_ = true;
                        
                        RemoteLogger.log(logPrefix + "get chunk by getPiece used: " + (getTimer() - getPieceStartTime_) + "ms");
                        
                        if (dispatcher_ != null)
                        {
                            DebugLogger.log(logPrefix + "dispatch DOWNLOAD_COMPLETE");
                            var streamingEvent:HTTPStreamingEvent = new HTTPStreamingEvent(
                                HTTPStreamingEvent.DOWNLOAD_COMPLETE,
                                false, // bubbles
                                false, // cancelable
                                0, // fragment duration
                                null, // scriptDataObject
                                FLVTagScriptDataMode.NORMAL, // scriptDataMode
                                lastReq_.uri, // urlString
                                downloadBytesCount_, // bytesDownloaded
                                HTTPStreamingEventReason.NORMAL, // reason
                                null /*this*/); // downloader
                            dispatcher_.dispatchEvent(streamingEvent);
                        }
                    }
                }
            }
        }
        
        private function handleHasChunkResp(event:PeerMsgEvent):void {
            var peer:Peer = event.peer;
            
            if(event.msg.obj["result"]){
                var chunk:Chunk = chunkCache_.findChunk(event.msg.obj["uri"]);
                if (event.msg.obj["calFrom"] > chunk.calFrom)
                {
                    chunk.upstreamChunkAvgSize = event.msg.obj["avgChunkSize"];
                    chunk.calFrom = event.msg.obj["calFrom"];
                }
            }
            
            peer.reqStatus.hasChunkFinished = true;
            DebugLogger.log(logPrefix + "handleHasChunkResp result=" + event.msg.obj["result"]);
            
            if (findPeers_ && !currentDetermined_) {
                if (event.msg.obj["result"])
                {
                    peer.reqStatus.willBeUsed = true;
                }
                
                determinIfEnoughPeers();
            }
        }
        
        private function handleHasChunkReq(event:PeerMsgEvent):void {
            var peer:Peer = event.peer;
            var chunk:Chunk = chunkCache_.findChunk(event.msg.obj["uri"]);
            
            var hasChunk:Boolean = true;
            if (chunk == null || chunk.state == ChunkState.INIT ||
                !chunk.isFromStableSource || !chunk.isReady
                /*|| status_ != NETWORK_JOINED*/
                ) {
                hasChunk = false;
            }
            
            var chunkDesc:String = "";
            if (chunk) {
                chunkDesc = chunk.toString();
            }
            
           var stats:Object = getPeerCountByGroup();
            
            DebugLogger.log(logPrefix + "handleHasChunkReq: uri: " + event.msg.obj["uri"] + " hasChunk: " + hasChunk
                            + " " + chunkDesc);
                            
            var chunkSize:int = chunkCache_.getAvgChunkSize();
            peer.respHasChunk(event.msg, event.msg.obj["uri"], hasChunk, stats["out"] + stats["none"], chunkSize, 
                chunkCache_.getReadyChunkCount()
                );
        }
        
        private function handleGoPushReq(event:PeerMsgEvent):void {
            var peer:Peer = event.peer;
            
            peer.respStatus.goPushUri = event.msg.obj["uri"];
            peer.respStatus.goPushPieceID = event.msg.obj["id"];
            peer.respStatus.goPushPieceCount = event.msg.obj["count"];
            peer.respStatus.goPushChunkOffset = event.msg.obj["offset"];
            peer.respStatus.goPushChunkLen = event.msg.obj["len"];
            
            peer.respStatus.mode = PeerStatus.PULL_TO_PUSH;
            peer.respStatus.goPushResult = true;
            
            DebugLogger.log(logPrefix + "handleGoPushReq");
            peer.respGoPush(event.msg, peer.respStatus.goPushResult);
        }
        
        private function handleGoPushReq2(event:PeerMsgEvent):void {
            var peer:Peer = event.peer;
            
            peer.respStatus.goPushUri = event.msg.obj["uri"];
            peer.respStatus.goPushPieceID = event.msg.obj["id"];
            peer.respStatus.goPushPieceCount = event.msg.obj["count"];
            peer.respStatus.goPushChunkOffset = event.msg.obj["chunkOffset"];
            peer.respStatus.goPushChunkLen = event.msg.obj["chunkLen"];
            
            DebugLogger.log(logPrefix + "handleGoPushReq2: " + peer.respStatus.toString());
            
            peer.respStatus.mode = PeerStatus.PUSH_MODE;
            
            var downstreamPeers:Vector.<String> = getDownstreamPeers();
            JavascriptCall.set_downstream_peers(downstreamPeers);
            
            peer.respGoPush2(event.msg, true);
            
            var chunk:Chunk = chunkCache_.findChunk(peer.respStatus.goPushUri);
            
            if(chunk){
                peer.respStatus.goPushIdx = chunk.idx;
                var newerChunks:Vector.<Chunk> = chunkCache_.getChunksNewer(chunk);
                pushCurrentChunks(newerChunks, peer);
            }
            else {
                // use resume to achive our purpose
                peer.respStatus.mode = PeerStatus.PUSH_MODE_RESUME;
                peer.respStatus.pushResumeUri = peer.respStatus.goPushUri;
            }
        }
        
        private function handlePingReq(event:PeerMsgEvent):void {
            var peer:Peer = event.peer;
            
            peer.respPing(event.msg);
        }
        
        private function setPieceInfo(size:int, count:int):void {
            if (pieceInfos_ == null) {
                pieceInfos_ = new Vector.<Object>();
            }
            else {
                pieceInfos_.splice(0, pieceInfos_.length);    
            }
            
            var pieceSize:int = Math.floor(size / count);
            for (var i:int; i < count; i++) {
                var obj:Object = new Object();
                obj['offset'] = pieceSize * i;
                obj['id'] = i;
                
                if (i == (count - 1)) {
                    obj['len'] = -1;
                }
                else {
                    obj['len'] = pieceSize;
                }
                
                pieceInfos_.push(obj);
            }
        }
        
        private function getDownstreamPeers():Vector.<String>
        {
            var ret:Vector.<String> = new Vector.<String>();
            
            for (var k:String in peers_) {
                var peer:Peer = peers_[k];
                
                if (peer.respStatus.mode == PeerStatus.PUSH_MODE) {
                    ret.push(peer.id);    
                }
            }
            
            return ret;
        }
        
        private function getUpstreamPeers():Vector.<String> {
            var ret:Vector.<String> = new Vector.<String>();
            
            for (var k:String in peers_) {
                var peer:Peer = peers_[k];
                
                if (peer.reqStatus.mode == PeerStatus.PUSH_MODE) {
                    ret.push(peer.id);    
                }
            }
            
            return ret;
        }
        
        private function handleGoPushRespConfirm(event:PeerMsgEvent):void {
            DebugLogger.log(logPrefix + "handleGoPushRespConfirm");
            var peer:Peer = event.peer;
            var msg:PeerMsg = event.msg;
            
            if (!peer.respStatus.goPushResult) {
                // failed
                peer.respStatus.mode = PeerStatus.PULL_MODE;
                return;
            }
            
            peer.respStatus.mode = PeerStatus.PUSH_MODE;
            
            var downstreamPeers:Vector.<String> = getDownstreamPeers();
            JavascriptCall.set_downstream_peers(downstreamPeers);
            
            // Update resp status, send already have data to peer
            var chunk:Chunk = chunkCache_.findChunk(peer.respStatus.goPushUri);
            /*
            var pieceSize:int = Math.floor(chunk.size / peer.respStatus.goPushPieceCount);
            peer.respStatus.goPushChunkOffset = pieceSize * peer.respStatus.goPushPieceID;
            
            if (peer.respStatus.goPushPieceCount == (peer.respStatus.goPushPieceID + 1)) {
                // last piece
                peer.respStatus.goPushChunkLen = -1;
            }
            else {
                peer.respStatus.goPushChunkLen = pieceSize;
            }
            */
            
            DebugLogger.log(logPrefix + "respStatus.mode==PeerStatus.PUSH_MODE"
                            + " goPushChunkOffset=" + peer.respStatus.goPushChunkOffset
                            + " goPushUri=" + peer.respStatus.goPushUri
                            + " goPushChunkLen=" + peer.respStatus.goPushChunkLen
                            );
            
            peer.respStatus.goPushIdx = chunk.idx;
            var newerChunks:Vector.<Chunk> = chunkCache_.getChunksNewer(chunk);
            pushCurrentChunks(newerChunks, peer);
        }
        
        private function pushCurrentChunks(chunks:Vector.<Chunk>, peer:Peer):void {
            for (var i:int = 0; i < chunks.length; i++) {
                var chunk:Chunk = chunks[i];
                
                if (chunk.isReady) {
                    var pieceData:ByteArray = chunk.getPieceData(peer.respStatus.goPushChunkOffset,
                                                peer.respStatus.goPushChunkLen);
                                                
                    if (pieceData != null && pieceData.length > 0) {
                        peer.pushPiece(chunk.uri, peer.respStatus.goPushChunkOffset, 
                                    peer.respStatus.goPushPieceID,
                                    pieceData, chunk.size, chunkCache_.indexData, chunk.isFromStableSource);
                    }
                    
                    DebugLogger.log(logPrefix + "pushCurrentChunks " + chunk.toString()
                                   + " goPushChunkOffset=" + peer.respStatus.goPushChunkOffset
                                   + " goPushChunkLen=" + peer.respStatus.goPushChunkLen);
                    peer.respStatus.goPushIdx = chunk.idx;
                }
                else {
                    break;
                }
            }
        }
        
        private function handleGoPushResp(event:PeerMsgEvent):void {
            var peer:Peer = event.peer;
            
            peer.reqStatus.mode = PeerStatus.PUSH_MODE;
        }
        
        private function handleGetPieceReq(event:PeerMsgEvent):void {
            var peer:Peer = event.peer;
            var chunk:Chunk = chunkCache_.findChunk(event.msg.obj["uri"]);
            var result:Object = new Object();
            
            if (chunk == null) {
                DebugLogger.log(logPrefix + "handleGetPieceReq chunk==null");
                result["result"] = false; 
            }
            else {
                DebugLogger.log(logPrefix + "handleGetPieceReq count!=pieces.length"
                        + " chunk.isReady=" + chunk.isReady + " chunk.size=" + chunk.size + " id=" + event.msg.obj["id"]
                        + " count=" + event.msg.obj["count"]);
                var p:Piece = chunk.buildPiece(event.msg.obj["id"], event.msg.obj["count"], event.msg.obj["offset"],
                                event.msg.obj["len"]);
                if (p == null) {
                    DebugLogger.log(logPrefix + "handleGetPieceReq piece==null");
                    result["result"] = false;
                }
                else {
                    DebugLogger.log(logPrefix + "handleGetPieceReq piece!=null");
                    result["result"] = true;
                    result["uri"] = chunk.uri;
                    result["id"] = event.msg.obj["id"];
                    result["content"] = p.content;
                    result["chunkOffset"] = p.chunkOffset;
                    result["chunkSize"] = chunk.size;
                    result["isFromStableSource"] = chunk.isFromStableSource;
                    result["idxData"] = chunkCache_.indexData;
                }
            }
            
            var msg:PeerMsg = new PeerMsg(result);
            msg.msgSubType = event.msg.msgSubType;
            peer.sendResp(msg, event.msg, P2PSetting.MSG_TIMEOUT);
        }
        
        private function createPeer(peerID:String, localPubPPConnected:Boolean):void {
            var peer:Peer = new Peer(peerID, session_, publishPoint_, this);
            if (localPubPPConnected) {
                peer.localPubPPConnected = true;
            }
            peers_[peerID] = peer;
            peer.addEventListener(PeerStatusEvent.PEER_STATUS, onPeerStatus);
            peer.addEventListener(PeerMsgEvent.MSG, onPeerMsg);
            peer.addEventListener(PeerMsgErrorEvent.ERROR, onPeerMsgError);
            peer.connect();
        }
        
        private function onPublishStart(event:PublishPointEvent):void { 
            tracker_ = TrackerFactory.instance.createTracker(TrackerFactory.HTTP_TRACKER, additionalInfo_['http_tracker']);
            tracker_.addEventListener(TrackerEvent.PEER_LIST, onPeerList);
            
            connectMorePeers();
        }
        
        public function connectMorePeers():void {
            // is already connecting.
            if (waitConnectResultPeers_.length > 0) {
                return;
            }
            tracker_.getPeers(session_.resouceName, int(P2PSetting.CHUNK_PEERS_COUNT * P2PSetting.CHUNK_PEERS_COUNT_FACTOR));
        }
        
        private function isFailedPeer(peerID:String):Boolean {
            for (var i:int = 0; i < failedPeers_.length; i++) {
                if (failedPeers_[i] == peerID) {
                    return true;
                }
            }
            
            return false;
        }
        
        private function onPeerList(event:TrackerEvent):void {
            DebugLogger.log(logPrefix + "onPeerList peers.length=" + event.peers.length);
            var isAnyNewPeer:Boolean = false;
            for (var i:int; i < event.peers.length; i++) {
                var peerID:String = event.peers[i];
                
                if (isFailedPeer(peerID)) {
                    continue;
                }
                
                // self
                if (peerID == session_.nearID) {
                    continue;
                }
                
                if (!peers_[peerID]) {
                    waitConnectResultPeers_.push(peerID);
                    //activeConnectPeerIds_.push(peerID);
                    createPeer(peerID, false);
                    isAnyNewPeer = true;
                }
            }
            
            //var e:P2PNetworkEvent = new P2PNetworkEvent(P2PNetworkEvent.STATUS);
            //e.code = P2PNetworkEvent.GET_PEER_LIST_OK;
            //dispatchEvent(e);
            
            if (!isAnyNewPeer) {
                var e2:P2PNetworkEvent = new P2PNetworkEvent(P2PNetworkEvent.STATUS);
                e2.code = P2PNetworkEvent.CONNECT_ACTIVE_PEERS_DONE;
                dispatchEvent(e2);
            }
        }
        
        private function onPeerConnectResult(isSuccess:Boolean, peer:Peer):void {
            for (var i:int = 0; i < waitConnectResultPeers_.length; i++) {
                if (peer.id == waitConnectResultPeers_[i]) {
                    waitConnectResultPeers_.splice(i, 1);
                    break;
                }
            }
            
            if (waitConnectResultPeers_.length == 0) {
                var event:P2PNetworkEvent = new P2PNetworkEvent(P2PNetworkEvent.STATUS);
                event.code = P2PNetworkEvent.CONNECT_ACTIVE_PEERS_DONE;
                dispatchEvent(event);
            }
        }
        
        private function onRespMsgSend(event:PeerStatusEvent):void {
            var total:int = 0;
            var outPeerNum:int;
            if (event.msg.isPieceMsg()) {
                outPeerNum = 0;
                for (var k:String in peers_) {
                    var peer:Peer = peers_[k];
                    
                    if (peer.respStatus.mode == PeerStatus.PUSH_MODE) {
                        outPeerNum++;
                    }
                    
                    total += peer.respWndPieceMsgSize;
                }
                
                if (total == 0) {
                    lastTimeRespQueueHitZero_ = getTimer();
                }
            }
            
            if (P2PSetting.REPORT_STATE_DURATION == -1) {
                return;
            }
            
            totalOutMsgSize_ += event.msg.getMsgSize();
            lastOutMsgSize_ += event.msg.getMsgSize();
            
            var now:Number = getTimer();
            
            if (isNaN(firstOutMsgTime_)) {
                firstOutMsgTime_ = now;
            }
            
            if (isNaN(lastOutMsgTime_)) {
                lastOutMsgTime_ = now;
            }
            else if ((now - lastOutMsgTime_ > P2PSetting.REPORT_STATE_DURATION)) {
                if (isNaN(outPeerNum)) {
                    outPeerNum = 0;
                    for (k in peers_) {
                        peer = peers_[k];
                        if (peer.respStatus.mode == PeerStatus.PUSH_MODE) {
                            outPeerNum++;
                        }
                    }
                }
                
                var timePassed:int = Math.floor((now - lastOutMsgTime_) / 1000);
                var speed:Number = Math.floor(lastOutMsgSize_ / (now - lastOutMsgTime_));
                var totalSpeed:Number = Math.floor(totalOutMsgSize_ / (now - firstOutMsgTime_));
                
                var logMsg:String = logPrefix + "[SPEED] Current speed(last " + timePassed + " seconds) is " + speed + "(KB/s); "
                                + "total speed is " + totalSpeed + "(KB/s). Current requiring chunk peers's count: " + outPeerNum;
                DebugLogger.log(logMsg);
                RemoteLogger.log(logMsg);
                
                JavascriptCall.set_downstream_speed(String(speed) + "KB/s", String(totalSpeed) + "KB/s");
                
                lastOutMsgSize_ = 0;
                lastOutMsgTime_ = now;
            }
        }
        
        private function onPeerStatus(event:PeerStatusEvent):void {
            var peerID:String = "null";
            if (event.peer) {
                peerID = event.peer.id;
            }
            DebugLogger.log(logPrefix + "onPeerStatus, code: " + event.code 
                    + " peer.id=" + peerID);
            switch(event.code) {
                case PeerStatusEvent.CONNECT_OK:
                    DebugLogger.log2(logPrefix + "connect success, used: " 
                            + (event.peer.connectFinishTime - event.peer.connectStartTime) + "ms");
                    onPeerConnectResult(true, event.peer);
                    if (event.peer.pendingReq) {
                        anyPendingReqSent_ = true;
                        event.peer.sendReq(event.peer.pendingReq, P2PSetting.MSG_TIMEOUT);
                    }
                    break;
                case PeerStatusEvent.CONNECT_ERROR:
                case PeerStatusEvent.CONNECT_TIMEOUT:
                    onPeerConnectResult(false, event.peer);
                    handlePeerStatusError(event)
                    break;
                case PeerStatusEvent.RESP_MSG_SEND:
                    onRespMsgSend(event);
                    break;
                default:
                    break;
            }
            //event.peer.close();
            //event.peer.sendHello();
        }
        
        private function addPeerToFailedList(peer:Peer):void {
            var tmp:Vector.<String> = failedPeers_.filter(function(item:String, index:int, v:Vector.<String>):Boolean { 
                if (peer.id == item) {
                    return true;
                }
                
                return false;
            } );
            
            if (tmp.length == 0) {
                failedPeers_.push(peer.id);
                
                if (failedPeers_.length > maxFailedPeerCount_) {
                    failedPeers_.shift();
                }
            }
        }
            
        private function handlePeerStatusError(event:PeerStatusEvent):void {
            // Currently we close peer when error happens.
            event.peer.close();
            
            handleDeletePeer(peers_[event.peer.id]);
            
            DebugLogger.log(logPrefix + "handlePeerStatusError: delete " + event.peer.id);
            delete peers_[event.peer.id];
            
            var downstreamPeers:Vector.<String> = getDownstreamPeers();
            JavascriptCall.set_downstream_peers(downstreamPeers);
            
            if (event.code == PeerStatusEvent.CONNECT_TIMEOUT) {
                addPeerToFailedList(event.peer);
            }
            
            var len:int = DictionaryUtil.len(peers_);
            if (len == 0) {
                if (hasPendingReq_ && !anyPendingReqSent_ && !getPeersErrorEventIssued_) {
                    getPeersErrorEventIssued_ = true;
                    var e:P2PNetworkEvent = new P2PNetworkEvent(P2PNetworkEvent.STATUS);
                    e.code = P2PNetworkEvent.GET_PEERS_ERROR;
                    dispatchEvent(e);
                }
            }
            
            if (findPeers_ && !currentDetermined_) {
                determinIfEnoughPeers();
            }
            
            DebugLogger.log(logPrefix + "handlePeerStatusError, peer count: " + DictionaryUtil.len(peers_));
        }
        
        private function setStatusForHasChunkReq():void {
            for (var k:String in peers_) {
                var peer:Peer = peers_[k];
                var ps:PeerReqStatus = peer.reqStatus;
                
                ps.hasChunkFinished = false;
                ps.hasChunkReqIdx = currentChunkIdx_;
            }
        }
        
        private function setToUsed(needSet:Boolean):void {
            var upstreamPeerIds:Vector.<String> = new Vector.<String>();
            for (var k:String in peers_) {
                var peer:Peer = peers_[k];
                if (peer.reqStatus.willBeUsed) {
                    if(needSet){
                        peer.reqStatus.isUsed = true;
                        upstreamPeerIds.push(peer.id);
                    }
                    peer.reqStatus.willBeUsed = false;
                }
            }
            
            JavascriptCall.set_upstream_peers(upstreamPeerIds);
        }
        
        private function getUsedPeerList():String {
            var ret:String = "";
            var isFirst:Boolean = true;
            for (var k:String in peers_) {
                var peer:Peer = peers_[k];
                
                if (peer.reqStatus.isUsed) {
                    if (!isFirst) {
                        ret += " ";
                    }
                    ret += peer.id.substr(0, 7);
                    
                    isFirst = false;
                }
            }
            
            return ret;
        }
        
        private function determinIfEnoughPeers():void {
            if (currentDetermined_) {
                throw new Error("is Determined");
            }
            
            DebugLogger.log(logPrefix + "determinIfEnoughPeers");
            
            var qualifiedPeers:int = 0;
            var allQueried:Boolean = true;
            for (var k:String in peers_) {
                var peer:Peer = peers_[k];
                var ps:PeerReqStatus = peer.reqStatus;
                
                if (ps.willBeUsed) {
                    qualifiedPeers++;
                }
                
                if ((ps.hasChunkReqIdx == currentChunkIdx_) && !ps.hasChunkFinished)
                {
                    allQueried = false;
                }
            }
            
            DebugLogger.log(logPrefix + "allQueried: " + allQueried
                + " desc: " + toString());
            
            var e:P2PNetworkEvent;
            if (qualifiedPeers >= qualifiedPeerCount_) {
                currentDetermined_ = true;
                setToUsed(true);
                RemoteLogger.log(logPrefix + "will get data from: " + getUsedPeerList());
                DebugLogger.log(logPrefix + "will get data from: " + getUsedPeerList());
                currentChunkIdx_++;
                status_ = NETWORK_JOINED;
                e = new P2PNetworkEvent(P2PNetworkEvent.STATUS);
                e.code = P2PNetworkEvent.GET_PEERS_OK;
                dispatchEvent(e);
                DebugLogger.log(logPrefix + "GET_PEERS_OK");
            }
            else if (allQueried && !getPeersErrorEventIssued_) {
                setToUsed(false);
                currentChunkIdx_++;
                getPeersErrorEventIssued_ = true;
                e = new P2PNetworkEvent(P2PNetworkEvent.STATUS);
                e.code = P2PNetworkEvent.GET_PEERS_ERROR;
                DebugLogger.log(logPrefix + "GET_PEERS_ERROR, qualifiedPeers=" + qualifiedPeers);
                dispatchEvent(e);
            }
        }
        
        override public function canHandleMorePeer(peerID:String):Boolean {
            var msgResult:Boolean = canHandleMorePeersCalByMsg();
            var peerResult:Boolean = canHandleMorePeersCalByPeer(peerID);
            
            DebugLogger.log(logPrefix + "msgResult=" + msgResult
                            + " peerResult=" + peerResult);
            
            return (msgResult && peerResult);
        }
        
        public function canHandleMorePeersCalByMsg():Boolean {
            if (lastTimeRespQueueHitZero_ == -1) {
                return true;
            }
            
            if (getTimer() - lastTimeRespQueueHitZero_ < 30) {
                return true;
            }
            
            var respCount:int = 0;
            for (var k:String in peers_) {
                var peer:Peer = peers_[k];
                respCount += peer.respWndMsgSize;
            }
            
            if (respCount == 0) {
                return true;
            }
            
            return false;
        }
        
        public function canHandleMorePeersCalByPeer(peerID:String):Boolean {
            var stats:Object = getPeerCountByGroup();
            
            /*
            for (var i:int = 0; i < activeConnectPeerIds_.length; i++) {
                if (activeConnectPeerIds_[i] == peerID) {
                    return true;
                }
            }
            */
            
            /*
            if (canBeConnected_ == false) {
                return canBeConnected_;
            }
            */
        
            /*
            if (stats['out'] > 2) {
                canBeConnected_ = false;
                return false;
            }
            */
            
            if (stats["out"] > P2PSetting.OUT_PEER_LIMIT) {
                DebugLogger.log(logPrefix + "OUT_PEER_LIMIT reached");
                return false;
            }
            
            return true;
        }
        
        override public function toString():String {
            var desc:String = "";
            
            var peerHeaderAdded:Boolean = false;
            for (var k:String in peers_) {
                if (!peerHeaderAdded) {
                    desc += "peers:";
                    peerHeaderAdded = true;
                }
                
                desc += " peer: " + peers_[k].toString();
            }
            
            desc += " needRepaire_=" + needRepaire_;
            
            return desc;
        }
        
        public function get pieceInfo():Vector.<Object> {
            return pieceInfos_;
        }
        
        private function get logPrefix():String {
            if (logPrefix_ != null) {
               return logPrefix_; 
            }
            
            logPrefix_ = session_.sessionID + " DefaultP2PNetwork ";

            return logPrefix;
        }
        
        //private var testTimer:Timer = new Timer(1000, 1);
        
        private var session_:RtmfpSession;
        private var publishPoint_:PublishPoint;
        private var tracker_:TrackerBase;
        private var peers_:Dictionary = new Dictionary();
        
        public static const INIT:String = "init";
        public static const SEARCHING_NETWORK:String = "searchingNetwork";
        public static const NETWORK_JOINED:String = "networkJoined";
        public static const RE_SEARCHING_NETWORK:String = "re-searchNetwork";
        public static const NETWORK_ERROR:String = "networkError";
        private var status_:String = INIT;
        private var chunkCache_:ChunkCache;
        
        private var lastReq_:Chunk = null;
        private var lastReqPieceID:int = -2;
        private var savedData_:ByteArray = new ByteArray();
        private var piecesWritten_:Vector.<Boolean> = null;
        private var pieceNextWrittenIdx_:int = 0;
        private var dispatcher_:IEventDispatcher;
        private var isPullMode_:Boolean = true;
        private var appendPushDataTimer_:Timer = null;
        private var setStatisticsTimer_:Timer = null;
        private var lastReqUri_:String = null;
        private var lastTimeout_:int;
        private var lastAppendPos_:int = 0;
        private var getchunkTimeoutCount_:int = 0;
        
        private var currentChunk_:Chunk = null;
        private var currentChunkPeers_:int = 0;
        private var currentChunkIdx_:int = 0;
        private var currentDetermined_:Boolean = false;
        private var qualifiedPeerCount_:int = 1;
        
        private var isOpen_:Boolean = false;
        private var isComplete_:Boolean = false;
        private var hasData_:Boolean = false;
        private var hasErrors_:Boolean = false;
        private var downloadDuration_:Number = 0;
        private var downloadBytesCount_:Number = 0;
        
        private var hasPendingReq_:Boolean = false;
        private var anyPendingReqSent_:Boolean = false;
        
        private var getChunkTimer_:Timer = null;
        private var needRespPingIds_:Vector.<String> = new Vector.<String>();
        private var needRespSpeedTestIds_:Vector.<String> = new Vector.<String>();
        private var speedTestId_:int = 0;
        private var lastSpeedTestId_:String;
        private var repairer_:P2PNetworkRepairer = null;
        
        private var failedPeers_:Vector.<String> = new Vector.<String>();
        private var maxFailedPeerCount_:int = 1000;
        
        private var waitConnectResultPeers_:Vector.<String> = new Vector.<String>();
        
        private var needRepairePeers_:Vector.<Peer> = new Vector.<Peer>();
        // 0: not repairing, 1: repairing
        private var needRepaireStates_:Vector.<int> = new Vector.<int>();
        private var repaireTimer_:Timer;
        private var REPAIRE_INTERVAL:int = 60;
        private var needRepaire_:Boolean = false;
        private var needRepaireUrl_:String;
        
        private var contentServers_:Vector.<String>;
        
        private var pieceInfos_:Vector.<Object> = null;
        private var findPeers_:Boolean = false;

        private var lastTimeRespQueueHitZero_:Number = -1;
        private var cleanUnUsedPeerTimer_:Timer;
        private var CUUPT_INTERVAL:int = P2PSetting.REPAIR_TOPO_TIMEOUT * 2;
        private var blockRepair_:Boolean = false;
        
        private var isFakeFailedPeers_:Boolean = false;
        private var getPeersErrorEventIssued_:Boolean = false;
        
        private var logPrefix_:String = null;
        
        private var canHandleGetPieceResp_:Boolean = true;
        private var getPieceStartTime_:Number;
        
        private var additionalInfo_:Object;
        
        private var totalOutMsgSize_:Number = 0;
        private var firstOutMsgTime_:Number;
        private var lastOutMsgSize_:Number = 0;
        private var lastOutMsgTime_:Number;
        
        private var pushPieceErrorUris:Vector.<String> = new Vector.<String>();
        
        //private var activeConnectPeerIds_:Vector.<String> = new Vector.<String>();
        //private var canBeConnected_:Boolean = true;
    }

}