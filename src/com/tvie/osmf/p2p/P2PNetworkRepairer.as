package com.tvie.osmf.p2p 
{
    import com.tvie.osmf.p2p.data.Chunk;
    import com.tvie.osmf.p2p.data.ChunkCache;
    import com.tvie.osmf.p2p.data.ChunkState;
    import com.tvie.osmf.p2p.data.Piece;
    import com.tvie.osmf.p2p.events.ContentServerEvent;
    import com.tvie.osmf.p2p.events.P2PNetworkEvent;
    import com.tvie.osmf.p2p.events.P2PNetworkRepairerEvent;
    import com.tvie.osmf.p2p.events.PeerMsgErrorEvent;
    import com.tvie.osmf.p2p.events.PeerMsgEvent;
    import com.tvie.osmf.p2p.events.PeerStatusEvent;
    import com.tvie.osmf.p2p.peer.IPeerMsgHook;
    import com.tvie.osmf.p2p.peer.Peer;
    import com.tvie.osmf.p2p.peer.PeerMsg;
    import com.tvie.osmf.p2p.peer.PeerStatus;
    import com.tvie.osmf.p2p.source.ContentServer;
    import com.tvie.osmf.p2p.source.IContentServerSelector;
    import com.tvie.osmf.p2p.source.SelectorFactory;
    import com.tvie.osmf.p2p.utils.P2PSetting;
    import com.tvie.osmf.p2p.utils.RemoteLogger;
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.TimerEvent;
    import flash.net.URLRequest;
    import flash.utils.ByteArray;
    import flash.utils.getTimer;
    import flash.utils.Timer;
    
    [Event(name = "Status", type = "com.tvie.osmf.p2p.events.P2PNetworkRepairerEvent")]
    
	/**
     * ...
     * @author dista
     */
    public class P2PNetworkRepairer extends EventDispatcher implements IPeerMsgHook
    {
        
        public function P2PNetworkRepairer(p2pNetwork:DefaultP2PNetwork, contentServers:Vector.<String>) 
        {
            contentServers_ = contentServers;
            logPrefix_ = p2pNetwork.session.sessionID + " P2PNetworkRepairer ";
            
            selector_ = selectorFactory_.createSelector(SelectorFactory.RR_SELECTOR, contentServers,
                                            "http");
            
            p2pNetwork_ = p2pNetwork;
            repireTopologyTimer_ = new Timer(RTT_INTERVAL, 1);
            repireTopologyTimer_.addEventListener(TimerEvent.TIMER_COMPLETE, repireTopologyCore);
            
            waitRespTimer_ = new Timer(WPT_INTERVAL, 1);
            waitRespTimer_.addEventListener(TimerEvent.TIMER_COMPLETE, onWaitRespTimeout);
            
            instanceID_ = "P2PNetworkRepairer_" + (new Date()).getTime();
            
            delayGetNewPeersTimer_ = new Timer(getNewPeerLimitDuration_, 1);
            delayGetNewPeersTimer_.addEventListener(TimerEvent.TIMER_COMPLETE, needGetMorePeers);
            
            p2pNetwork_.addEventListener(P2PNetworkEvent.STATUS, onP2PNetworkStatus);
            
            contentServerDp2_.addEventListener(ContentServerEvent.STATUS, onContentServerStatus);
        }
        
        private function needGetMorePeers(event:TimerEvent):void {
            p2pNetwork_.connectMorePeers();
            getNewPeerLastTime_ = getTimer();
        }
        
        private function addDataToChunk(offset:int, len:int, id:int):Object {
            dataBuffer_.position = offset;
            var data:ByteArray = new ByteArray();
            dataBuffer_.readBytes(data, 0, len);
            data.position = 0;
            dataBuffer_.position = offset + len;
            
            var piece:Piece = new Piece(id);
            // set piece property
            piece.content = data;
            piece.chunkOffset = offset;
            piece.contentLength = len;
            piece.isReady = true;
            
            //var oldPieceSize:int = chunk.pieces.length;
            
            var chunk:Chunk = p2pNetwork_.chunkCache.findChunk(url_);
            var isChanged:Boolean = chunk.addPiece(piece);
            
            var ret:Object = new Object();
            ret["chunk"] = chunk;
            ret['isChanged'] = isChanged;
            
            return ret;
        }
        
        private function handleData(isComplete:Boolean):void {
            var nrp:Object = null;
            if (needRepairePieceInfo_.length > 0) {
                nrp = needRepairePieceInfo_[0];
            }
            
            var chunk:Chunk = null;
            var obj:Object = null;
            while (nrp) {
                var offset:int = nrp['offset'];
                var len:int = nrp['len'];
                var id:int = nrp['id'];
                
                var updated:Boolean = false;
                if (len != -1) {
                    if (dataBuffer_.position <= offset
                        && dataBuffer_.length >= (offset + len)) {
                        obj = addDataToChunk(offset, len, id);
                        chunk = obj["chunk"];
                        DebugLogger.log(logPrefix_ + "chunkUpdate1, uri=" + chunk.uri + " size=" + chunk.size);
                        if(obj["isChanged"]){
                            p2pNetwork_.chunkUpdated(chunk);
                        }
                        updated = true;
                    }
                }
                
                if (isComplete && !updated) {
                    if (offset < dataBuffer_.length) {
                        obj = addDataToChunk(offset, dataBuffer_.length - offset, id);
                        chunk = obj["chunk"];
                        chunk.calSize();
                        DebugLogger.log(logPrefix_ + "chunkUpdate2, uri=" + chunk.uri + " size=" + chunk.size);
                        if(obj["isChanged"]){
                            p2pNetwork_.chunkUpdated(chunk);
                        }
                        updated = true;
                    }
                }
                
                if (updated) {
                    needRepairePieceInfo_.shift();
                    
                    if (needRepairePieceInfo_.length > 0) {
                        nrp = needRepairePieceInfo_[0];
                        continue;
                    }
                }
                
                break;
            }
            
            if (isComplete) {
                if (chunk == null) {
                    chunk = p2pNetwork_.chunkCache.findChunk(url_);
                }
                chunk.calSize();
                
                // if there is still piece left, it is mean the chunk's length is less than need repaired piece's
                // offset
                if (needRepairePieceInfo_.length > 0) {
                    p2pNetwork_.chunkUpdated(chunk);
                    /*
                    DebugLogger.log(logPrefix_ + " bug: chunk: " + chunk.toString() + " needRepairPieceInfo: " + 
                                getneedRepairePieceInfoDesc()
                    );
                    */
                }
                
                if (chunk.state == ChunkState.LOADING_FROM_SOURCE) {
                    chunk.state = ChunkState.LOAD_FROM_SOURCE_DONE;
                }
                else if (chunk.state == ChunkState.LOADING_FROM_HYBRID) {
                    chunk.state = ChunkState.LOAD_FROM_HYBRID_DONE;
                }
            }
        }
        
        private function getneedRepairePieceInfoDesc():String {
            var ret:String;
            
            if (needRepairePieceInfo_.length == 0) {
                ret = "[empty]";
            }
            else {
                ret = "" + " size=" + needRepairePieceInfo_.length + " infos: ";
                
                for (var i:int = 0; i < needRepairePieceInfo_.length; i++) {
                    ret += " offset=" + needRepairePieceInfo_[i]["offset"]
                          + " len=" + needRepairePieceInfo_[i]["len"] 
                          + " id=" + needRepairePieceInfo_[i]["id"];
                }
            }
            
            return ret;
        }
        
        private function onContentServerStatus(event:ContentServerEvent):void {
            if(event.data != null){
                event.data.readBytes(dataBuffer_, dataBuffer_.length, event.data.length);
            }
            switch(event.code) {
                case ContentServerEvent.PROGRESS:
                    handleData(false);
                    break;
                case ContentServerEvent.COMPLETE:
                    RemoteLogger.log(logPrefix_ + "repairData complete: " + url_);
                    handleData(true);
                    break;
                case ContentServerEvent.ERROR:
                    RemoteLogger.log(logPrefix_ + "repairData error: " + url_);
                    var e:P2PNetworkRepairerEvent = new P2PNetworkRepairerEvent(P2PNetworkRepairerEvent.ON_STATUS);
                    e.code = P2PNetworkRepairerEvent.REPAIR_DATA_ERROR;
                    e.failedDataUrl = event.url;
                    e.failedDataReason = event.reason;
                    dispatchEvent(e);
                    break;
            }
        }
        
        public function get isRepairTopo():Boolean {
            return isRepairTopo_;
        }
        
        public function set isRepairTopo(val:Boolean):void {
            isRepairTopo_ = val;
        }
        
        private function onP2PNetworkStatus(event:P2PNetworkEvent):void {
            if (!isRepairTopo_) {
                return;
            }
            DebugLogger.log(logPrefix_ + "code=" + event.code);
            switch(event.code) {
                case P2PNetworkEvent.CONNECT_ACTIVE_PEERS_DONE:
                    state_ = INIT;
                    break;
                default:
                    break
            }
        }
        
        private function onWaitRespTimeout(event:TimerEvent):void {
            for (var i:int = 0; i < peerCandidates_.length; i++) {
                if (peerCandidatesStates_[i] == waitState_) {
                    if (peerCandidatesResults_[i] == -1) {
                        peerCandidatesResults_[i] = 0;
                        
                        if (waitState_ == WAIT_FOR_GO_PUSH_RESP) {
                            resetFailedIdx(peerCandidates_[i]);
                            peerCandidatesStates_[i] = WAIT_FOR_GO_PUSH_RESP_FAILED;
                        }
                        else if (waitState_ == WAIT_FOR_PING_RESP) {
                            peerCandidatesStates_[i] = WAIT_FOR_PING_RESP_FAILED;
                        }
                        else if (waitState_ == WAIT_FOR_HAS_CHUNK_RESP) {
                            peerCandidatesStates_[i] = WAIT_FOR_HAS_CHUNK_RESP_FAILED;
                        }
                        else if (waitState_ == WAIT_FOR_STOP_PUSH_RESP) {
                            resetFailedIdx(peerCandidates_[i]);
                            peerCandidatesStates_[i] = WAIT_FOR_STOP_PUSH_RESP_FAILED;
                        }
                    }
                }
            }
            
            // do not care about old pings
            currentReqId_ = "";
            
            switch(waitState_) {
                case WAIT_FOR_PING_RESP:
                    state_ = WAIT_FOR_PING_RESP_FAILED;
                    break;
                case WAIT_FOR_HAS_CHUNK_RESP:
                    state_ = WAIT_FOR_HAS_CHUNK_RESP_FAILED;
                    break;
                case WAIT_FOR_GO_PUSH_RESP:
                    state_ = WAIT_FOR_GO_PUSH_RESP_FAILED;
                    break;
                case WAIT_FOR_STOP_PUSH_RESP:
                    state_ = WAIT_FOR_STOP_PUSH_RESP_FAILED;
                    break;
            }
        }
        
        public function hook(event:PeerMsgEvent):Boolean {
            // TODO: more state_
            if (state_ != WAIT_FOR_GO_PUSH_RESP
                && state_ != WAIT_FOR_PING_RESP
                && state_ != WAIT_FOR_HAS_CHUNK_RESP) {
                return false;
            }
            
            if (event.msg.msgType == PeerMsg.RESP) {
                switch(event.msg.msgSubType) {
                    case PeerMsg.SUB_TYPE_PING:
                        return handlePingResp(event);
                    case PeerMsg.SUB_TYPE_HAS_CHUNK:
                        return handleHasChunkResp(event);
                    case PeerMsg.SUB_TYPE_GO_PUSH_MODE2:
                        return handleGoPushMode2Resp(event);
                    case PeerMsg.SUB_TYPE_STOP_PUSH:
                        return handleStopPushResp(event);
                }
            }
            
            return false;
        }
        
        private function setPeerPingState(peer:Peer):void {
            for (var i:int = 0; i < peerCandidates_.length; i++) {
                if (peerCandidates_[i].id == peer.id) {
                    peerCandidatesResults_[i] = 1;
                }
            }
        }
        
        private function setPeerHasChunkState(peer:Peer, result:int):void {
            for (var i:int = 0; i < peerCandidates_.length; i++) {
                if (peerCandidates_[i].id == peer.id) {
                    peerCandidatesResults_[i] = result;
                    
                    if (result == 0 && (getTimer() - peer.connectFinishTime) < P2PSetting.REPAIR_SECOND_CHANGE_TIME) {
                        peerCandidatesStates_[i] = INIT;
                        peerCandidatesResults_[i] = -1;
                        hasInitPeers_ = true;
                        DebugLogger.log(logPrefix_ + "set hasChunk=false peer to INIT");
                    }
                    else if (result == 0) {
                        peerCandidatesStates_[i] = WAIT_FOR_HAS_CHUNK_RESP_FAILED;
                    }
                }
            }
        }
        
        private function setPeerGoPushState(peer:Peer, result:int):void {
            if(result == 1){
                peer.reqStatus.mode = PeerStatus.PUSH_MODE;
            }
            for (var i:int = 0; i < peerCandidates_.length; i++) {
                if (peerCandidates_[i].id == peer.id) {
                    peerCandidatesResults_[i] = result;
                    
                    if (peerCandidatesResults_[i] == 0) {
                        peerCandidatesStates_[i] = WAIT_FOR_GO_PUSH_RESP_FAILED;
                    }
                }
            }
            
            if (result == 0) {
                resetFailedIdx(peer);
            }
        }
        
        private function setPeerStopPushState(peer:Peer, result:int):void {
            for (var i:int = 0; i < peerCandidates_.length; i++) {
                if (peerCandidates_[i].id == peer.id) {
                    peerCandidatesResults_[i] = result;
                }
            }
        }
        
        private function resetFailedIdx(peer:Peer):void {
            var idx:int = findPeerIdx(peer);
            
            if (idx == -1) {
                throw new Error("should not be -1");
            }
            
            for (var i:int = 0; i < failedPeerHandlerIdx_.length; i++) {
                if (failedPeerHandlerIdx_[i] == idx) {
                    failedPeerHandlerIdx_[i] = -1;
                    break;
                }
            }
        }
        
        private function findPeerIdx(peer:Peer):int {
            for (var i:int = 0; i < peerCandidates_.length; i++) {
                if (peerCandidates_[i].id == peer.id) {
                    return i;
                }
            }
            
            return -1;
        }
        
        private function isCurrentActionAllDone(state:String):Boolean {
            for (var i:int = 0; i < peerCandidatesResults_.length; i++) {
                if (peerCandidatesStates_[i] == state &&
                    peerCandidatesResults_[i] == -1) {
                    return false;
                }
            }
            
            return true;
        }
        
        private function getSuccessCount(state:String):int {
            var ret:int = 0;
            for (var i:int = 0; i < peerCandidatesResults_.length; i++) {
                if (peerCandidatesStates_[i] == state
                    && peerCandidatesResults_[i] == 1) {
                    ret++;
                }
            }
            
            return ret;
        }
        
         private function giveFleshPeerSecondChance():void {
            var now:int = getTimer();
            for (var i:int = 0; i < peerCandidatesResults_.length; i++) {
                if ((peerCandidatesStates_[i] == WAIT_FOR_HAS_CHUNK_RESP) &&
                    ((now - peerCandidates_[i].connectFinishTime) < 8000) &&
                    (peerCandidatesResults_[i] == 0)
                    ) {
                    peerCandidatesResults_[i] = -1;
                    peerCandidatesStates_[i] = INIT;
                    hasInitPeers_ = true;
                }
            }
        }
        
        private function setHasChunkSuccessToInit():void {
            for (var i:int = 0; i < peerCandidatesResults_.length; i++) {
                if ((peerCandidatesStates_[i] == WAIT_FOR_HAS_CHUNK_RESP)
                    && peerCandidatesResults_[i] == 1) {
                    peerCandidatesResults_[i] = -1;
                    peerCandidatesStates_[i] = INIT;
                    hasInitPeers_ = true;    
                }
            }
        }
        
        /*
         * state trans:
         * wait for connection ok -> wait for ping resp 
         * -> wait for has chunk resp -> wait for go push resp
         * 
         */
        
        private function sendHasChunkForPeers():void {
            currentReqId_ = instanceID_ + reqIdx_;
            reqIdx_++;
            
            var chunk:Chunk = p2pNetwork_.chunkCache.getHasChunkReqChunk(2);
            if (chunk) {
                repairP2PUrl_ = chunk.uri;
            }
            
            var hasReq:Boolean = false;
            for (var i:int = 0; i < peerCandidates_.length; i++) {
                var state:String = peerCandidatesStates_[i];
                
                if (state != WAIT_FOR_PING_RESP) {
                    continue;
                }
                
                var pingResult:int = peerCandidatesResults_[i];
                if (pingResult == 1) {
                    var peer:Peer = peerCandidates_[i];
                    peerCandidatesStates_[i] = WAIT_FOR_HAS_CHUNK_RESP;
                    peerCandidatesResults_[i] = -1;
                    peer.reqHasChunk(repairP2PUrl_, currentReqId_);
                    peerCandidatesHasChunkUrl_[i] = repairP2PUrl_;
                    peerCandidatesHasChunkSendTimes_[i] = getTimer();
                    hasReq = true;
                }
            }
            
            if (hasReq) {
                waitState_ = WAIT_FOR_HAS_CHUNK_RESP;
                waitRespTimer_.reset();
                waitRespTimer_.start();
            }
        }
        
        private function connectMorePeers():Boolean {
            DebugLogger.log(logPrefix_ + "connectMorePeers");
            
            var stats:Object = p2pNetwork_.getPeerCountByGroup();
            
            if ((stats["in"] + stats["out"]) > 100) {
                DebugLogger.log(logPrefix_ + "limit meet, no more peer can be connected");
                return false;
            }
            
            if ((getTimer() - repairTopoStartTime_) > P2PSetting.REPAIR_TOPO_TIMEOUT) {
                DebugLogger.log(logPrefix_ + "repair topo timeout");
                return false;
            }
            
            if (getNewPeerLastTime_ == -1) {
                p2pNetwork_.connectMorePeers();
                getNewPeerLastTime_ = getTimer();
            }
            else {
                if ((getTimer() - getNewPeerLastTime_) > getNewPeerLimitDuration_) {
                    p2pNetwork_.connectMorePeers();
                    getNewPeerLastTime_ = getTimer();
                }
                else {
                    delayGetNewPeersTimer_.reset();
                    delayGetNewPeersTimer_.start();
                    DebugLogger.log(logPrefix_ + "delay connect more peers");
                }
            }
            
            return true;
        }
        
        private function gotoHasChunkProcessOrGetMorePeers():void {
            DebugLogger.log(logPrefix_ + "gotoHasChunkProcessOrGetMorePeers");

            if (getSuccessCount(WAIT_FOR_PING_RESP) > 0) {
                state_ = WAIT_FOR_HAS_CHUNK_RESP;
                
                sendHasChunkForPeers();
            }
            else {
                if (repairOneTime_) {
                    state_ = REPAIR_FAILED;
                }
                else{
                    if(connectMorePeers()){
                        state_ = WAIT_FOR_NEW_PEER_LIST;
                    }
                    else {
                        state_ = REPAIR_FAILED_PENDING;
                    }
                }
            }
        }
        
        private function stopPushOrGetMorePeers():void {
            var anyWait:Boolean = false;
            currentReqId_ = instanceID_ + reqIdx_;
            reqIdx_++;
            for (var i:int = 0; i < failedPeerHandlerIdx_.length; i++) {
                if (failedPeerHandlerIdx_[i] != -1) {
                    var idx:int = failedPeerHandlerIdx_[i];
                    if ((peerCandidatesStates_[idx] == WAIT_FOR_GO_PUSH_RESP) && 
                         (peerCandidatesResults_[idx] == 1)) {
                        var peer:Peer = peerCandidates_[i];
                        peer.reqStatus.mode = PeerStatus.PULL_MODE;
                        peer.reqStopPush(currentReqId_);
                        peerCandidatesStates_[idx] = WAIT_FOR_STOP_PUSH_RESP;
                        peerCandidatesResults_[idx] = -1;
                        anyWait = true;
                    }
                }
            }
            
            if (!anyWait) {
                if (repairOneTime_) {
                    state_ = REPAIR_FAILED;
                }
                else{
                    if(connectMorePeers()){
                        state_ = WAIT_FOR_NEW_PEER_LIST;
                    }
                    else {
                        state_ = REPAIR_FAILED_PENDING;
                    }
                }
            }
            else {
                waitState_ = WAIT_FOR_STOP_PUSH_RESP;
                state_ = WAIT_FOR_STOP_PUSH_RESP;
                waitRespTimer_.reset();
                waitRespTimer_.start();
            }
        }
        
        private function gotoDoneOrGetMorePeers():void {
            DebugLogger.log(logPrefix_ + "gotoDoneOrGetMorePeers");
            var isAllDone:Boolean = true;
            
            for (var i:int = 0; i < failedPeerHandlerIdx_.length; i++) {
                if (failedPeerHandlerIdx_[i] == -1) {
                    isAllDone = false;
                    break;
                }
            }
            
            if (isAllDone) {
                state_ = DONE;
            }
            else {
                stopPushOrGetMorePeers();
            }
        }
        
        private function getFirstWaitChunkRespIdx():int {
            for (var i:int = 0; i < peerCandidates_.length; i++) {
                if (peerCandidatesStates_[i] == WAIT_FOR_HAS_CHUNK_RESP
                    && peerCandidatesResults_[i] == 1) {
                    return i;        
                }
            }
            
            return -1;
        }
        
        private function sendGoPushForPeers():void {
            DebugLogger.log(logPrefix_ + "sendGoPushForPeers");
            currentReqId_ = instanceID_ + reqIdx_;
            reqIdx_++;
            
            var chunk:Chunk = p2pNetwork_.chunkCache.getHasChunkReqChunk(1);
            
            for (var i:int = 0; i < failedPeers_.length; i++) {
                if (failedPeerHandlerIdx_[i] != -1) {
                    continue;
                }
                var fp:Peer = failedPeers_[i];
                var idx:int = getFirstWaitChunkRespIdx();
                
                if (idx == -1) {
                    // should never happen
                    throw new Error("should not happen, bug");
                }
                
                var url:String = peerCandidatesHasChunkUrl_[idx];
                if (chunk) {
                    url = chunk.uri;
                }
                
                var np:Peer = peerCandidates_[idx];
                
                np.reqGoPush2(url, fp.reqStatus.pushChunkOffset, fp.reqStatus.pushChunkLen, 
                              fp.reqStatus.pushPieceID, fp.reqStatus.pushPieceCount,
                              currentReqId_);
                RemoteLogger.log(logPrefix_ + "pushChunkOffset=" + fp.reqStatus.pushChunkOffset
                                + " pushChunkLen=" + fp.reqStatus.pushChunkLen
                                );
                DebugLogger.log(logPrefix_ + "pushChunkOffset=" + fp.reqStatus.pushChunkOffset
                                + " pushChunkLen=" + fp.reqStatus.pushChunkLen
                                );
                
                failedPeerHandlerIdx_[i] = idx;
                np.reqStatus.pushPieceID = fp.reqStatus.pushPieceID;
                np.reqStatus.pushPieceCount = fp.reqStatus.pushPieceCount;
                np.reqStatus.pushChunkOffset = fp.reqStatus.pushChunkOffset;
                np.reqStatus.pushChunkLen = fp.reqStatus.pushChunkLen;
                peerCandidatesStates_[idx] = WAIT_FOR_GO_PUSH_RESP;
                peerCandidatesResults_[idx] = -1;
            }
            
            state_ = WAIT_FOR_GO_PUSH_RESP;
            waitRespTimer_.reset();
            waitRespTimer_.start();
        }
        
        private function getUnHandledFailedPeerCount():int {
            var ret:int = 0;
            for (var i:int = 0; i < failedPeerHandlerIdx_.length; i++) {
                if (failedPeerHandlerIdx_[i] == -1)
                {
                    ret++;
                }
            }
            
            return ret;
        }
        
        private function gotoGoPushProcessOrGetMorePeers():void {
            DebugLogger.log(logPrefix_ + "gotoGoPushProcessOrGetMorePeers");
            giveFleshPeerSecondChance();
            if (getSuccessCount(WAIT_FOR_HAS_CHUNK_RESP) >= getUnHandledFailedPeerCount()) {
                sendGoPushForPeers();
            }
            else {
                if (repairOneTime_) {
                    state_ = REPAIR_FAILED;
                }
                else{
                    setHasChunkSuccessToInit();
                    if(connectMorePeers()){
                        state_ = WAIT_FOR_NEW_PEER_LIST;
                    }
                    else {
                        state_ = REPAIR_FAILED_PENDING;
                    }
                }
            }
        }
        
        private function handlePingResp(event:PeerMsgEvent):Boolean {
            DebugLogger.log(logPrefix_ + "handlePingResp");
            var externalID:String = event.msg.obj["externalID"];
            
            if (externalID == currentReqId_) {
                setPeerPingState(event.peer);
                if (isCurrentActionAllDone(WAIT_FOR_PING_RESP)) {
                    waitRespTimer_.stop();
                    
                    gotoHasChunkProcessOrGetMorePeers();
                }
                return true;
            }
            
            if (externalID && externalID.indexOf(instanceID_) == 0) {
                return true;
            }
            
            return false;
        }
        
        private function handleGoPushMode2Resp(event:PeerMsgEvent):Boolean {
            DebugLogger.log(logPrefix_ + "handleGoPushMode2Resp");
            var externalID:String = event.msg.obj['externalID'];
            if (externalID == currentReqId_) {
                var result:int = 1;
                if (!event.msg.obj['result']) {
                    result = 0;
                }
                setPeerGoPushState(event.peer, result);
                if (isCurrentActionAllDone(WAIT_FOR_GO_PUSH_RESP)) {
                    waitRespTimer_.stop();
                    
                    gotoDoneOrGetMorePeers();
                }
                return true;
            }
            
            if (externalID && externalID.indexOf(instanceID_) == 0) {
                return true;
            }
            
            return false;
        }
        
        private function onStopPushFinished():void {
            for (var i:int = 0; i < peerCandidates_.length; i++) {
                if (peerCandidatesStates_[i] == WAIT_FOR_STOP_PUSH_RESP) {
                    resetFailedIdx(peerCandidates_[i]);
                    peerCandidatesStates_[i] = INIT;
                    peerCandidatesResults_[i] = -1;
                    hasInitPeers_ = true;
                }
            }
            
            if (repairOneTime_) {
                state_ = REPAIR_FAILED;
            }
            else{
                state_ = INIT;
            }
        }
        
        private function handleStopPushResp(event:PeerMsgEvent):Boolean {
            var externalID:String = event.msg.obj['externalID'];
            
            if (externalID == currentReqId_) {
                setPeerStopPushState(event.peer, 1);
                if (isCurrentActionAllDone(WAIT_FOR_STOP_PUSH_RESP)) {
                    waitRespTimer_.stop();
                    
                    onStopPushFinished();
                }
            }
            
            if (externalID && externalID.indexOf(instanceID_) == 0) {
                return true;
            }
            
            return false;
        }
        
        private function handleHasChunkResp(event:PeerMsgEvent):Boolean {
            var externalID:String = event.msg.obj['id'];
            if (externalID == currentReqId_) {
                var result:int = 1;
                if (!event.msg.obj['result']) {
                    result = 0;
                }
                DebugLogger.log(logPrefix_ + "handleHasChunkResp: peer.id=" + event.peer.id + " result=" + result);
                setPeerHasChunkState(event.peer, result);
                if (isCurrentActionAllDone(WAIT_FOR_HAS_CHUNK_RESP)) {
                    waitRespTimer_.stop();
                    
                    gotoGoPushProcessOrGetMorePeers();
                }
                return true;
            }
            
            if (externalID && externalID.indexOf(instanceID_) == 0) {
                return true;
            }
            
            return false;
        }
        
        private function repireTopologyCore(event:TimerEvent):void {
            //DebugLogger.log(logPrefix_ + "state=" + state_);
            switch(state_) {
                case INIT:
                    var unUsedPeers:Vector.<Peer> = p2pNetwork_.getUnUsedPeer();
                    
                    if (repairOneTime_) {
                        DebugLogger.log(logPrefix_ + " repairOneTimeConnectMorePeerUsed_=" + repairOneTimeConnectMorePeerUsed_
                            + " unUsedPeers.length=" + unUsedPeers.length + " failedPeers_.length=" + failedPeers_.length);
                        // first time we check if there are 1.5x peers
                        // second time we check if there are 1x peers
                        if ((!repairOneTimeConnectMorePeerUsed_ && (unUsedPeers.length < failedPeers_.length * 1.5)) || (
                            repairOneTimeConnectMorePeerUsed_ && (unUsedPeers.length < failedPeers_.length)
                            )) {
                            if (repairOneTimeConnectMorePeerUsed_)
                            {
                                state_ = REPAIR_FAILED;
                                break;
                            }
                            else {
                                repairOneTimeConnectMorePeerUsed_ = true;
                                if(connectMorePeers()){
                                    state_ = WAIT_FOR_NEW_PEER_LIST;
                                }else {
                                    state_ = REPAIR_FAILED_PENDING;
                                }
                                
                                break;
                            }
                        }
                    }
                    
                    var now:int = getTimer();
                    if (unUsedPeers.length > 0 || hasInitPeers_) {
                        var peerCandidatesLen:int = peerCandidates_.length;
                        for (var j:int; j < unUsedPeers.length; j++) {
                            peerCandidates_.push(unUsedPeers[j]);   
                        }
                                            
                        currentReqId_ = instanceID_ + reqIdx_;
                        reqIdx_++;
                        var sendReq:Boolean = false;
                        for (var i:int = peerCandidatesLen; i < peerCandidates_.length; i++) {
                            peerCandidates_[i].msgHooker = this;
                            peerCandidatesStates_.push(INIT);
                            peerCandidatesResults_.push( -1);
                            peerCandidatesHasChunkUrl_.push("");
                            peerCandidatesHasChunkSendTimes_.push( -1);
                        }
                        
                        for (i = 0; i < peerCandidates_.length; i++) {
                            if(peerCandidatesStates_[i] == INIT){
                                peerCandidates_[i].reqPing(currentReqId_);
                                peerCandidatesStates_[i] = WAIT_FOR_PING_RESP;
                                peerCandidatesResults_[i] = -1;
                                sendReq = true;
                            }
                        }
                            
                        if (sendReq) {
                            state_ = WAIT_FOR_PING_RESP;
                            waitState_ = WAIT_FOR_PING_RESP;
                            waitRespTimer_.reset();
                            waitRespTimer_.start();
                        }
                        
                        hasInitPeers_ = false;
                    }
                    else {
                        if(connectMorePeers()){
                            state_ = WAIT_FOR_NEW_PEER_LIST;
                        }
                        else {
                            state_ = REPAIR_FAILED_PENDING;
                        }
                    }
                    break;
                case WAIT_FOR_NEW_PEER_LIST:
                    // do nothing
                    break;
                case WAIT_FOR_PING_RESP_FAILED:
                    gotoHasChunkProcessOrGetMorePeers();
                    break;
                case WAIT_FOR_HAS_CHUNK_RESP:
                    // do nothing
                    break;
                case WAIT_FOR_HAS_CHUNK_RESP_FAILED:
                    gotoGoPushProcessOrGetMorePeers();
                    break;
                case WAIT_FOR_GO_PUSH_RESP_FAILED:
                    gotoDoneOrGetMorePeers();
                    break;
                case WAIT_FOR_STOP_PUSH_RESP_FAILED:
                    onStopPushFinished();
                    break;
                case DONE:
                    isRepairTopo_ = false;
                    DebugLogger.log(logPrefix_ + " repairTopology OK");
                    RemoteLogger.log(logPrefix_ + " repairTopology OK");
                    // dispatch event
                    var repairOKEvent:P2PNetworkRepairerEvent = new P2PNetworkRepairerEvent(
                                    P2PNetworkRepairerEvent.ON_STATUS);
                    repairOKEvent.code = P2PNetworkRepairerEvent.REPAIR_OK;
                    repairOKEvent.failedPeers = failedPeers_;
                    repairOKEvent.newPeers = getFixedNewPeers();
                    changePeerStates(repairOKEvent);
                    dispatchEvent(repairOKEvent);
                    break;
                case REPAIR_FAILED_PENDING:
                    if (repairOneTime_) {
                        state_ = REPAIR_FAILED;
                    }
                    break;
                case REPAIR_FAILED:
                    isRepairTopo_ = false;
                    DebugLogger.log(logPrefix_ + " repairTopology failed");
                    // dispatch event
                    var repairFailedEvent:P2PNetworkRepairerEvent = new P2PNetworkRepairerEvent(
                                    P2PNetworkRepairerEvent.ON_STATUS);
                    repairFailedEvent.code = P2PNetworkRepairerEvent.REPAIR_ERROR;
                    repairFailedEvent.failedPeers = failedPeers_;
                    dispatchEvent(repairFailedEvent);
                    break;
                default:
                    break;
            }
            
            if (isRepairTopo_) {
                repireTopologyTimer_.reset();
                repireTopologyTimer_.start();
            }
        }
        
        private function changePeerStates(event:P2PNetworkRepairerEvent):void {
            var i:int = 0;
            for (i = 0; i < event.failedPeers.length; i++) {
                event.failedPeers[i].reqStatus.isUsed = false;
            }
            
            for (i = 0; i < event.newPeers.length; i++) {
                event.newPeers[i].reqStatus.isUsed = true;
            }
        }
        
        private function getFixedNewPeers():Vector.<Peer> {
            var ret:Vector.<Peer> = new Vector.<Peer>();
            
            for (var i:int = 0; i < failedPeerHandlerIdx_.length; i++) {
                var candidateIdx:int = failedPeerHandlerIdx_[i];
                ret.push(peerCandidates_[candidateIdx]);
            }
            
            return ret;
        }
        
        public function repairTopology(failedPeers:Vector.<Peer>, missedUrl:String, repairOneTime:Boolean = false):void {
            if (isRepairTopo_) {
                throw new Error("is repairing");    
            }
            
            DebugLogger.log(logPrefix_ + " repairTopology " + missedUrl);
            
            repairP2PUrl_ = missedUrl;
            repairTopoStartTime_ = getTimer();
            repairOneTime_ = repairOneTime;
            repairOneTimeConnectMorePeerUsed_ = false;
            
            isRepairTopo = true;
            state_ = INIT;
            failedPeers_ = failedPeers;
            peerCandidates_ = new Vector.<Peer>();
            peerCandidatesStates_ = new Vector.<String>();
            peerCandidatesHasChunkUrl_ = new Vector.<String>();
            peerCandidatesResults_ = new Vector.<int>();
            peerCandidatesHasChunkSendTimes_ = new Vector.<int>();
            hasInitPeers_ = false;
            
            failedPeerHandlerIdx_ = new Vector.<int>();
            for (var i:int = 0; i < failedPeers_.length; i++) {
                failedPeerHandlerIdx_.push( -1);
            }
            
            repireTopologyTimer_.reset();
            repireTopologyTimer_.start();
        }
        
        private function isUrlRepairing(url:String):Boolean {
            for (var i:int = 0; i < repairingList.length; i++) {
                if (repairingList[i] == url) {
                    return true;
                }
            }
            
            return false;
        }
        
        public function repairData(url:String, timeout:int):void {
            url_ = url;
           
            if (isUrlRepairing(url)) {
                return;
            }
            
            if (state_ == REPAIR_FAILED_PENDING && p2pNetwork_.chunkCache.isNewestChunkReady()) {
                state_ = REPAIR_FAILED;
            }
            
            if (state_ == REPAIR_FAILED) {
                return;
            }
            
            RemoteLogger.log(logPrefix_ + "repairData url=" + url);
            DebugLogger.log(logPrefix_ + "repairData url=" + url);
            
            if (repairingList.length >= 100) {
                repairingList.shift();
            }
            
            var chunkCache:ChunkCache = p2pNetwork_.chunkCache;
            
            var chunk:Chunk = chunkCache.findChunk(url);
            if (chunk == null) {
                chunk = new Chunk(url);
                chunk.state = ChunkState.LOADING_FROM_SOURCE;
                chunkCache.addChunk(chunk);
            }
            else {
                chunk.state = ChunkState.LOADING_FROM_HYBRID;
            }
            
            chunk.isFromStableSource = false;
            
            if (chunk.isReady) {
                return;
            }
           
            chunk.isFromStableSource = false;
            chunk.state = ChunkState.LOADING_FROM_SOURCE;
            
            // TODO: caculate missing pieces
            
            dataBuffer_.position = 0;
            dataBuffer_.length = 0;
            
            needRepairePieceInfo_.splice(0, needRepairePieceInfo_.length);
            var pieceInfo:Vector.<Object> = p2pNetwork_.pieceInfo;
            var lastJ:int = 0;
            var hasElement:Boolean = false;
            for (var i:int = 0; i < pieceInfo.length; i++) {
                hasElement = false;
                
                // because pieceInfo and chunk.pieces is all ordered, so we only compare the first one
                for (var j:int = lastJ; j < chunk.pieces.length; /*void*/) {
                    hasElement = true;
                    if (chunk.pieces[j].chunkOffset > pieceInfo[i]["offset"]) {
                        needRepairePieceInfo_.push(pieceInfo[i]);
                    }
                    else {
                        lastJ = j + 1;
                    }
                    
                    break;
                }
                
                if (!hasElement) {
                    needRepairePieceInfo_.push(pieceInfo[i]);
                }
            }
            
            if (needRepairePieceInfo_.length == 0) {
                throw new Error("BUG, this should not happen");
            }
            
            if (contentServer_) {
                contentServer_.close();
            }
            contentServer_ = selector_.select();
            
            var urlRequest:URLRequest = new URLRequest(url);
            contentServer_.open2(urlRequest, contentServerDispatcher_, timeout, contentServerDp2_);
        }
        
        private var repairP2PUrl_:String;
        private var repairTopoStartTime_:int;
        private var failedPeers_:Vector.<Peer>;
        private var failedPeerHandlerIdx_:Vector.<int>;
        private var url_:String;
        private var state_:String;
        private var repireTopologyTimer_:Timer;
        private var peerCandidates_:Vector.<Peer>;
        
        // For ping: -1: not have resp, 0: failed, 1: success
        private var peerCandidatesResults_:Vector.<int>;
        private var peerCandidatesHasChunkUrl_:Vector.<String>;
        private var peerCandidatesHasChunkSendTimes_:Vector.<int>;
        private var hasInitPeers_:Boolean = false;
        private var peerCandidatesStates_:Vector.<String>;
        private var p2pNetwork_:DefaultP2PNetwork;
        private var waitRespTimer_:Timer;
        private static const RTT_INTERVAL:int = 60;
        private static const WPT_INTERVAL:int = 10000;
        
        private static const INIT:String = "Init";
        private static const WAIT_FOR_PING_RESP:String = "WaitForPingResp";
        private static const WAIT_FOR_PING_RESP_FAILED:String = "WaitForPingRespFailed";
        private static const WAIT_FOR_NEW_PEER_LIST:String = "WaitForNewPeerList";
        private static const WAIT_FOR_NEW_PEER_CONNECT:String = "WaitForNewPeerConnect";
        private static const WAIT_FOR_HAS_CHUNK_RESP:String = "WaitForHasChunkResp";
        private static const WAIT_FOR_HAS_CHUNK_RESP_FAILED:String = "WaitForHasChunkRespFailed";
        private static const WAIT_FOR_GO_PUSH_RESP:String = "WaitForGoPushResp";
        private static const WAIT_FOR_GO_PUSH_RESP_FAILED:String = "WaitForGoPushRespFailed";
        private static const WAIT_FOR_STOP_PUSH_RESP:String = "WaitForStopPushResp";
        private static const WAIT_FOR_STOP_PUSH_RESP_FAILED:String = "WaitForStopPushRespFailed";
        private static const REPAIR_FAILED_PENDING:String = "RepairFailedPending";
        private static const REPAIR_FAILED:String = "RepairFailed";
        private static const DONE:String = "Done";
        
        private var instanceID_:String;
        private var reqIdx_:int = 0;
        private var currentReqId_:String;
        
        private var waitState_:String;
        
        private var isRepairTopo_:Boolean = false;
        
        private var repairingList:Vector.<String> = new Vector.<String>();
        
        private var selectorFactory_:SelectorFactory = new SelectorFactory();
        private var selector_:IContentServerSelector = null;
        private var contentServer_:ContentServer = null;
        private var contentServers_:Vector.<String>;
        private var contentServerDispatcher_:EventDispatcher = new EventDispatcher();
        private var contentServerDp2_:EventDispatcher = new EventDispatcher();
        
        private var needRepairePieceInfo_:Vector.<Object> = new Vector.<Object>();
        private var dataBuffer_:ByteArray = new ByteArray();
        
        private var logPrefix_:String;
        private var getNewPeerLimitDuration_:int = 10000;
        private var getNewPeerLastTime_:int = -1;
        private var delayGetNewPeersTimer_:Timer;
        private var repairOneTime_:Boolean;
        private var repairOneTimeConnectMorePeerUsed_:Boolean;
    }

}