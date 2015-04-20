package com.tvie.osmf.p2p.peer 
{
    import adobe.utils.CustomActions;
    import com.tvie.osmf.p2p.data.Chunk;
    import com.tvie.osmf.p2p.events.PeerMsgErrorEvent;
    import com.tvie.osmf.p2p.events.PeerMsgEvent;
    import com.tvie.osmf.p2p.events.PeerStatusEvent;
    import com.tvie.osmf.p2p.events.PeerTestEvent;
    import com.tvie.osmf.p2p.events.PublishPointEvent;
    import com.tvie.osmf.p2p.events.SubscribeMsgEvent;
    import com.tvie.osmf.p2p.events.SubscriberEvent;
    import com.tvie.osmf.p2p.JavascriptCall;
    import com.tvie.osmf.p2p.P2PNetworkBase;
    import com.tvie.osmf.p2p.RtmfpSession;
    import com.tvie.osmf.p2p.utils.P2PSetting;
    import flash.display.InteractiveObject;
    import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
    import flash.events.TimerEvent;
    import flash.net.NetStream;
    import flash.utils.ByteArray;
    import flash.utils.getTimer;
    import flash.utils.Timer;
	
    [Event(name = "PeerStatus", type = "com.tvie.osmf.p2p.events.PeerStatusEvent")]
    [Event(name = "Message", type = "com.tvie.osmf.p2p.events.PeerMsgEvent")]
    [Event(name = "PeerMsgError", type = "com.tvie.osmf.p2p.events.PeerMsgErrorEvent")]
    
    [Event(name = "PeerTest", type = "com.tvie.osmf.p2p.events.PeerTestEvent")]
    
	/**
     * ...
     * @author dista
     */
    public class Peer extends EventDispatcher 
    {
        public function Peer(id:String = null, session:RtmfpSession = null, publishPoint:PublishPoint = null,
                            p2pNetwork:P2PNetworkBase = null) 
        {
            session_ = session;
            id_ = id;
            publishPoint_ = publishPoint;
            p2pNetwork_ = p2pNetwork;
        }
        
        public function get id():String {
            return id_;
        }
        
        public function set localPubPPConnected(val:Boolean):void {
            localPubPPConnected_ = val;
            
            DebugLogger.log(session_.sessionID + " Peer: localPubPPConnected");
            
            if (localPriPublishPoint_) {
                //throw new Error("localPriPublishPoint_ is already created");
                return;
            }
            
            localPriPublishPoint_ = new PublishPoint(session_, false, p2pNetwork_);
            localPriPublishPoint_.addEventListener(PublishPointEvent.PUBLISH_START, onPriPublishPointStart);
            localPriPublishPoint_.addEventListener(PublishPointEvent.NEW_PEER_CONNECTED, onPriPublishPointPeerConnect);
            localPriPublishPoint_.publish(id_);
        }
        
        public function get isReady():Boolean {
            if (localPriPublishPoint_ && localPriPublishPoint_.hasSubscriber
                && remotePriSub_ && remotePriSub_.isSubscribed) {
                return true;
            }
            
            return false;
        }
        
        public function get idDesc():String {
            return id.substr(0, 7);
        }
        
        public function get localPubPPConnected():Boolean {
            return localPubPPConnected_;
        }
        
        public function connect():void {
            connectTimer_ = new Timer(P2PSetting.PEER_CONNECT_TIMEOUT, 1);
            connectTimer_.addEventListener(TimerEvent.TIMER_COMPLETE, onConnectTimeout);
            connectTimer_.start();
            
            connectStartTime = getTimer();
            
            remotePubSub_ = new Subscriber(session_, id_, id_);
            remotePubSub_.addEventListener(SubscriberEvent.ON_STATUS, onRPubSubStatus);
            remotePubSub_.subscribe();
        }
        
        public function close():void {
            if (localPriPublishPoint_) {
                localPriPublishPoint_.close();
            }
            
            if (remotePriSub_) {
                remotePriSub_.close();
            }
            
            if (remotePubSub_) {
                remotePubSub_.close();
            }
            
            if (connectTimer_) {
                connectTimer_.stop();
            }
        }
        
        private function onConnectTimeout(event:TimerEvent):void {
            if (!isReady) {
                DebugLogger.log(session_.sessionID + " Peer: connect " + id_ + " timeout");
                var e:PeerStatusEvent = new PeerStatusEvent(PeerStatusEvent.PEER_STATUS,
                    false, false, this, PeerStatusEvent.CONNECT_TIMEOUT);
                dispatchEvent(e);
            }
        }
        
        private function onPriPublishPointStart(event:PublishPointEvent):void {
            DebugLogger.log(session_.sessionID + " Peer: onPriPublishPointStart");
        }
        
        private function onPriPublishPointPeerConnect(event:PublishPointEvent):void {
            if (this.isReady) {
                connectFinishTime = getTimer();
                var e:PeerStatusEvent = new PeerStatusEvent(PeerStatusEvent.PEER_STATUS, false, false, this,
                                        PeerStatusEvent.CONNECT_OK);
                dispatchEvent(e);
            }
        }
        
        private function onRPubSubStatus(event:SubscriberEvent):void {
            DebugLogger.log(session_.sessionID + " Peer: onRpSubStatus");
            
            if (event.code == SubscriberEvent.SUBSCRIBE_OK) {
                // this mean remote has created a private publish for us
                // now we can connect to that private publish
                if (remotePriSub_) {
                    throw new Error("remotePriSub_ is already created");
                }
                
                remotePriSub_ = new Subscriber(session_, id_, session_.nearID);
                remotePriSub_.addEventListener(SubscriberEvent.ON_STATUS, onRPriSubStatus);
                remotePriSub_.addEventListener(SubscribeMsgEvent.ON_MSG, onRPriSubMsg);
                remotePriSub_.subscribe();
            }
            else if (event.code == SubscriberEvent.SUBSCRIBE_ERROR) {
                // subscribe failed
                var e:PeerStatusEvent = new PeerStatusEvent(PeerStatusEvent.PEER_STATUS, false, false, this, 
                    PeerStatusEvent.CONNECT_ERROR);
                
                dispatchEvent(e);
            }
        }
        
        private function onRPriSubStatus(event:SubscriberEvent):void {
            DebugLogger.log(session_.sessionID + " Peer: onRPriSubStatus, code: " + event.code);
            if (this.isReady) {
                connectFinishTime = getTimer();
                var e:PeerStatusEvent = new PeerStatusEvent(PeerStatusEvent.PEER_STATUS, false, false, this,
                        PeerStatusEvent.CONNECT_OK);
                dispatchEvent(e);
            }
        }
        
        private function onRPriSubMsg(event:SubscribeMsgEvent):void {
            DebugLogger.log(session_.sessionID + " Peer: msg_id=" + event.msg[PeerMsg.MSG_ID]);
            var msg:PeerMsg = new PeerMsg(event.msg);
            var sendMsgFound:Boolean = false;
            if (event.msg.hasOwnProperty(PeerMsg.REQ_MSG_ID)) {
                DebugLogger.log(session_.sessionID + " Peer: Response, req_msg_id=" + event.msg[PeerMsg.REQ_MSG_ID]
                                + " msg_id=" + event.msg[PeerMsg.MSG_ID]);
                if(event.msg[PeerMsg.REQ_MSG_ID] != -1){
                    for (var i:int = 0; i < outReqWnd_.length; i++) {
                        if (outReqWnd_[i].obj[PeerMsg.MSG_ID] == event.msg[PeerMsg.REQ_MSG_ID]) {
                            outReqWnd_[i].endSend();
                            outReqWnd_.splice(i, 1);
                            sendMsgFound = true;
                            break;
                        }
                    }
                    
                    if (outReqWnd_.length > 0) {
                        DebugLogger.log(session_.sessionID + " Peer: onRPriSubMsg, queue length: " + outReqWnd_.length);
                        DebugLogger.log(session_.sessionID + " Peer: [req] send " + outReqWnd_[0].msgSubType + " msg_id=" + outReqWnd_[0].msgID
                                        + " peerID=" + id_);
                        
                        statistics.outBytes += outReqWnd_[0].getMsgSize();
                        localPriPublishPoint_.broadcast(PeerMsg.MSG_NAME, outReqWnd_[0].obj);
                    }
                    else {
                        canSendReq_ = true;
                    }
                }
                else {
                    // push message
                    sendMsgFound = true;
                }
                
                if (sendMsgFound || msg.msgSubType == PeerMsg.SUB_TYPE_PING) {
                    if (msg.careConfirm) {
                        DebugLogger.log(session_.sessionID + " Peer: sendRespConfirm for msg_id=" + msg.msgID);
                        sendRespConfirm(msg);
                    }
                    var e:PeerMsgEvent = new PeerMsgEvent(PeerMsgEvent.MSG, msg, this);
                    dispatchEvent(e);
                }
            }
            else if (event.msg.hasOwnProperty(PeerMsg.RESP_CONFIRM))
            {
                DebugLogger.log(session_.sessionID + " Peer: RESP_CONFIRM, resp_msg_id=" + event.msg[PeerMsg.RESP_MSG_ID]
                                + " outRespWnd_.length=" + outRespWnd_.length);
                                
                if (event.msg[PeerMsg.RESP_MSG_ID] == respStatus_.lastPushPieceId) {
                    respStatus_.lastPushPieceUsedTime = getTimer() - respStatus_.lastPushPieceSendTime;
                }
                                
                var foundResp:PeerMsg = null;
                // last large resp is send successfully
                for (i = 0; i < outRespWnd_.length; i++) {
                    if (outRespWnd_[i].obj[PeerMsg.MSG_ID] == event.msg[PeerMsg.RESP_MSG_ID]) {
                        outRespWnd_[i].endSend();
                        foundResp = outRespWnd_[i];
                        outRespWnd_.splice(i, 1);
                        break;
                    }
                }
                
                DebugLogger.log(session_.sessionID + " Peer: outRespWnd_.length=" + outRespWnd_.length);
                
                while(true){
                    if (outRespWnd_.length > 0) {
                        DebugLogger.log(session_.sessionID + " Peer: [resp] send " + outRespWnd_[0].msgSubType + " msg_id=" + outRespWnd_[0].msgID
                                        + " peerID=" + id_
                                        );
                        if (outRespWnd_[0].addSendingTimestamp) {
                            outRespWnd_[0].sendTimestamp = new Date();
                            DebugLogger.log(session_.sessionID + " Peer: sendDelayTime=" + outRespWnd_[0].sendDelayTime + "(milliseconds)");
                        }
                        statistics.outBytes += outRespWnd_[0].getMsgSize();
                        localPriPublishPoint_.broadcast(PeerMsg.MSG_NAME, outRespWnd_[0].obj);
                        
                        var respMsgSendEvent:PeerStatusEvent = new PeerStatusEvent(PeerStatusEvent.PEER_STATUS);
                        respMsgSendEvent.code = PeerStatusEvent.RESP_MSG_SEND;
                        respMsgSendEvent.msg = outRespWnd_[0];
                        dispatchEvent(respMsgSendEvent);
                        
                        if (outRespWnd_[0].careConfirm) {
                            if (outRespWnd_[0].isPieceMsg()) {
                                respStatus_.lastPushPieceId = outRespWnd_[0].msgID;
                                respStatus_.lastPushPieceSendTime = getTimer();
                                respStatus_.lastPushPieceSize = outRespWnd_[0].getMsgSize();
                            }
                            
                            break;
                        }
                        else {
                            outRespWnd_[0].endSend();
                            outRespWnd_.shift();
                        }
                    }
                    else {
                        canSendResp_ = true;
                        break;
                    }
                }
                
                DebugLogger.log(session_.sessionID + " Peer: 2 outRespWnd_.length=" + outRespWnd_.length);
                if (!foundResp) {
                    DebugLogger.log(session_.sessionID + " Peer: foundResp=null");
                }
                else {
                    DebugLogger.log(session_.sessionID + " Peer: foundResp.needConfirm=" + foundResp.needConfirm);
                }
                
                if (foundResp && foundResp.needConfirm) {
                    event.msg[PeerMsg.TYPE] = PeerMsg.CONFIRM;
                    msg = new PeerMsg(event.msg);
                    e = new PeerMsgEvent(PeerMsgEvent.MSG, msg, this);
                    dispatchEvent(e);
                }
            }
            else {
                DebugLogger.log(session_.sessionID + " Peer: Request,"
                            + " msg_id=" + event.msg[PeerMsg.MSG_ID])
                            + " msg_type=" + event.msg[PeerMsg.SUB_TYPE];
                e = new PeerMsgEvent(PeerMsgEvent.MSG, msg, this);
                dispatchEvent(e);
            }
        }
        
        private function sendRespConfirm(respMsg:PeerMsg):void {
            var respMsgId:int = respMsg.msgID;
            var obj:Object = new Object();
            obj[PeerMsg.RESP_CONFIRM] = true;
            obj[PeerMsg.MSG_ID] = msgId++;
            obj[PeerMsg.SUB_TYPE] = respMsg.msgSubType;
            obj[PeerMsg.RESP_MSG_ID] = respMsgId;
            
            if (respMsg.obj.hasOwnProperty('__opacity')) {
                obj['__respOpacity'] = respMsg.obj['__opacity'];
            }
            
            var msg:PeerMsg = new PeerMsg(obj);
            statistics.outBytes += msg.getMsgSize();
            localPriPublishPoint_.broadcast(PeerMsg.MSG_NAME, msg.obj);
        }
        
        public function sendReq(msg:PeerMsg, timeout:int = 0, sendNow:Boolean = false ):void {            
            msg.obj[PeerMsg.MSG_ID] = msgId++;
            msg.obj[PeerMsg.TYPE] = PeerMsg.REQ;
            
            DebugLogger.log(session_.sessionID + " Peer: sendReq, msg_id=" + msg.obj[PeerMsg.MSG_ID]); 
                     
            if (!sendNow) {
                outReqWnd_.push(msg);
                msg.startSend(timeout);
            }
            msg.addEventListener(PeerMsgErrorEvent.ERROR, onReqMsgError);
            
            if (canSendReq_ || sendNow)
            {
                if(!sendNow){
                    canSendReq_ = false;
                }
                DebugLogger.log(session_.sessionID + " Peer: [req] send " + msg.msgSubType + " msg_id=" + msg.msgID
                                + " peerID=" + id_
                                );
                
                statistics.outBytes += msg.getMsgSize();
                localPriPublishPoint_.broadcast(PeerMsg.MSG_NAME, msg.obj);
            }
        }
        
        public function sendResp(msg:PeerMsg, req:PeerMsg, timeout:int = 0, needConfirm:Boolean = false, sendNow:Boolean = false,
                                careConfirm:Boolean = true):void {
            
            if (sendNow && careConfirm) {
                throw new ArgumentError("sendNow and careConfirm can't be all true");
            }
            
            msg.obj[PeerMsg.MSG_ID] = msgId++;
            
            DebugLogger.log(session_.sessionID + " Peer: sendResp, msg_id=" + msg.obj[PeerMsg.MSG_ID]);
            
            if(req != null){
                msg.obj[PeerMsg.REQ_MSG_ID] = req.msgID;
            }
            else {
                msg.obj[PeerMsg.REQ_MSG_ID] = -1;    
            }
            
            msg.obj[PeerMsg.TYPE] = PeerMsg.RESP;
            
            if (needConfirm) {
                msg.needConfirm = true;
            }
            
            if (careConfirm) {
                msg.careConfirm = true;
            }
            
            if (msg.addQueueTimestamp) {
                msg.queueTimestamp = new Date();
            }
            
            if (!sendNow) {
                outRespWnd_.push(msg);
                msg.startSend(timeout);
            }
            msg.addEventListener(PeerMsgErrorEvent.ERROR, onRespMsgError);
            DebugLogger.log(session_.sessionID + " Peer: canSendResp_: " + canSendResp_
                            + " outRespWnd_.length=" + outRespWnd_.length);
            for (var i:int = 0; i < outRespWnd_.length; i++) {
                DebugLogger.log(session_.sessionID + " Peer: out msg type: " + outRespWnd_[i].msgSubType
                                + " msg_id=" + outRespWnd_[i].msgID);
            }
            
            if (canSendResp_ || sendNow) {
                if(!sendNow){
                    canSendResp_ = false;
                }
                DebugLogger.log(session_.sessionID + " Peer: [resp] send " + msg.msgSubType + " msg_id=" + msg.msgID
                                + " peerID=" + id_);
                if (msg.addSendingTimestamp) {
                    msg.sendTimestamp = new Date();
                }
                statistics.outBytes += msg.getMsgSize();
                localPriPublishPoint_.broadcast(PeerMsg.MSG_NAME, msg.obj);
                                                    
                var respMsgSendEvent:PeerStatusEvent = new PeerStatusEvent(PeerStatusEvent.PEER_STATUS);
                respMsgSendEvent.code = PeerStatusEvent.RESP_MSG_SEND;
                respMsgSendEvent.msg = msg;
                dispatchEvent(respMsgSendEvent);
                
                while(true && !sendNow){
                    if (!careConfirm) {
                        msg.endSend();
                        outRespWnd_.shift();
                    }
                    else {
                        if (outRespWnd_[0].isPieceMsg()) {
                            respStatus_.lastPushPieceId = outRespWnd_[0].msgID;
                            respStatus_.lastPushPieceSendTime = getTimer();
                            respStatus_.lastPushPieceSize = outRespWnd_[0].getMsgSize();
                        }
                        
                        break;
                    }
                    
                    if (outRespWnd_.length > 0) {
                        msg = outRespWnd_[0];
                        careConfirm = msg.careConfirm;
                        statistics.outBytes += msg.getMsgSize();
                        localPriPublishPoint_.broadcast(PeerMsg.MSG_NAME, msg.obj);
                        
                        respMsgSendEvent = new PeerStatusEvent(PeerStatusEvent.PEER_STATUS);
                        respMsgSendEvent.code = PeerStatusEvent.RESP_MSG_SEND;
                        respMsgSendEvent.msg = msg;
                        dispatchEvent(respMsgSendEvent);
                    }
                    else {
                        canSendResp_ = true;
                        break;
                    }
                }
            }
        }
        
        private function onReqMsgError(event:PeerMsgErrorEvent):void {
            for (var i:int = 0; i < outReqWnd_.length; i++) {
                if (outReqWnd_[i].obj[PeerMsg.MSG_ID] == event.msg.msgID) {
                    outReqWnd_.splice(i, 1);
                    break;
                }
            }

            reqError_ = true;
            reqErrorCode_ = event.code;
            reqErrorTime_ = new Date();
            
            DebugLogger.log(session_.sessionID + " Peer: reqErrorCode_=" + event.code
                    + ", current_queue_count=" + outReqWnd_.length + " msg.subType=" + event.msg.msgSubType);
            
            var newEvent:PeerMsgErrorEvent = new PeerMsgErrorEvent(PeerMsgErrorEvent.ERROR);
            newEvent.code = event.code;
            newEvent.msg = event.msg;
            newEvent.peer = this;
                
            dispatchEvent(newEvent);
        }
        
        private function onRespMsgError(event:PeerMsgErrorEvent):void {
            for (var i:int = 0; i < outRespWnd_.length; i++) {
                if (outRespWnd_[i].obj[PeerMsg.MSG_ID] == event.msg.msgID) {
                    outRespWnd_.splice(i, 1);
                    break;
                }
            }
            
            // TODO: do something with timeout
            
            respError_ = true;
            respErrorCode_ = event.code;
            respErrorTime_ = new Date();
            
            DebugLogger.log(session_.sessionID + " Peer: respErrorCode_=" + event.code
                + ", current_queue_count=" + outRespWnd_.length + " msg.subType=" + event.msg.msgSubType);
                
            var newEvent:PeerMsgErrorEvent = new PeerMsgErrorEvent(PeerMsgErrorEvent.ERROR);
            newEvent.code = event.code;
            newEvent.msg = event.msg;
            newEvent.peer = this;
            
            dispatchEvent(newEvent);
        }
        
        public function get pendingMsgCount():int {
            return outReqWnd_.length + outRespWnd_.length;
        }
        
        public function get requestWindow():Vector.<PeerMsg> {
            return outReqWnd_;
        }
        
        public function reqHasChunk(uri:String, id:String = null):void {
            var msg:PeerMsg = buildReqHasChunk(uri, id);
            sendReq(msg, P2PSetting.MSG_TIMEOUT);
        }
        
        public function buildReqHasChunk(uri:String, id:String = null):PeerMsg {
            var msg:PeerMsg = new PeerMsg();
            msg.msgSubType = PeerMsg.SUB_TYPE_HAS_CHUNK;
            msg.obj["uri"] = uri;
            msg.obj["id"] = id;
            
            return msg;
        }
        
        public function reqClose():void {
            var msg:PeerMsg = new PeerMsg();
            msg.msgSubType = PeerMsg.SUB_TYPE_CLOSE;
            
            sendReq(msg, P2PSetting.MSG_TIMEOUT, true);
        }
        
        public function respHasChunk(req:PeerMsg, uri:String, result:Boolean, outPeerNumber:int, avgChunkSize:int, calFrom:int):void {
            var msg:PeerMsg = new PeerMsg();
            msg.msgSubType = PeerMsg.SUB_TYPE_HAS_CHUNK;
            msg.obj["uri"] = uri;
            msg.obj["result"] = result;
            msg.obj["id"] = req.obj["id"];
            msg.obj["outPeerNumber"] = outPeerNumber;
            msg.obj["avgChunkSize"] = avgChunkSize;
            msg.obj["calFrom"] = calFrom;
            
            sendResp(msg, req, P2PSetting.MSG_TIMEOUT);
        }
        
        public function reqGetPiece(uri:String, pieceId:int, pieceCount:int, chunkOffset:int, chunkLen:int):void {
            var msg:PeerMsg = new PeerMsg();
            msg.msgSubType = PeerMsg.SUB_TYPE_GET_PIECE;
            msg.obj["uri"] = uri;
            msg.obj["id"] = pieceId;
            msg.obj["count"] = pieceCount;
            msg.obj["offset"] = chunkOffset;
            msg.obj["len"] = chunkLen;
            
            sendReq(msg, P2PSetting.MSG_TIMEOUT);
        }
        
        public function reqPing(externalID:String = null):void {
            var msg:PeerMsg = new PeerMsg();
            msg.msgSubType = PeerMsg.SUB_TYPE_PING;
            msg.obj["pingId"] = reqStatus.lastPingId;
            msg.obj["externalID"] = externalID;
            
            sendReq(msg, P2PSetting.MSG_TIMEOUT, true);
        }
        
        public function reqSpeedTest(id:String):void {
            var msg:PeerMsg = new PeerMsg();
            msg.msgSubType = PeerMsg.SUB_TYPE_SPEED_TEST;
            msg.obj['start_time'] = new Date();
            msg.obj['id'] = id;
            
            sendReq(msg, P2PSetting.MSG_TIMEOUT, false);
        }
        
        public function respSpeedTest(req:PeerMsg):void {
            var msg:PeerMsg = new PeerMsg();
            msg.msgSubType = PeerMsg.SUB_TYPE_SPEED_TEST;
            msg.obj['start_time'] = req.obj['start_time'];
            msg.obj['id'] = req.obj['id'];
            
            sendResp(msg, req, P2PSetting.MSG_TIMEOUT, false, false, false);
        }
        
        public function respPing(req:PeerMsg):void {
            var msg:PeerMsg = new PeerMsg();
            msg.msgSubType = PeerMsg.SUB_TYPE_PING;
            msg.obj["pingId"] = req.obj["pingId"];
            msg.obj['externalID'] = req.obj['externalID'];
            
            sendResp(msg, req, P2PSetting.MSG_TIMEOUT, false, true, false);
        }
        
        public function pushPieceError(uri:String):void {
            var msg:PeerMsg = new PeerMsg();
            msg.msgSubType = PeerMsg.SUB_TYPE_PUSH_PIECE_ERROR;
            msg.obj["uri"] = uri;
            
            sendResp(msg, null, P2PSetting.MSG_TIMEOUT, false, true, false);
        }
        
        public function pushPiece(uri:String, offset:int, id:int, data:ByteArray, chunkSize:int, 
                        idxData:ByteArray, 
                        isFromStableSource:Boolean):void {
            var msg:PeerMsg = new PeerMsg();
            msg.msgSubType = PeerMsg.SUB_TYPE_PUSH_PIECE;
            msg.obj["uri"] = uri;
            msg.obj["offset"] = offset;
            msg.obj["id"] = id;
            msg.obj["chunkSize"] = chunkSize;
            msg.obj["data"] = data;
            msg.obj["idxData"] = idxData;
            msg.obj["isFromStableSource"] = isFromStableSource;
            msg.addSendingTimestamp = true;
            msg.addQueueTimestamp = true;
            
            msg.obj['lastUsedTime'] = respStatus_.lastPushPieceUsedTime;
            msg.obj['lastSize'] = respStatus_.lastPushPieceSize;
            
            sendResp(msg, null, P2PSetting.MSG_TIMEOUT, false);
        }
        
        public function reqGoPush(uri:String, pieceId:int, pieceCount:int, offset:int, len:int):void {
            var msg:PeerMsg = new PeerMsg();
            msg.msgSubType = PeerMsg.SUB_TYPE_GO_PUSH_MODE;
            msg.obj["uri"] = uri;
            msg.obj["id"] = pieceId;
            msg.obj["count"] = pieceCount;
            msg.obj["offset"] = offset;
            msg.obj["len"] = len;
            
            sendReq(msg, P2PSetting.MSG_TIMEOUT);
        }
        
        public function reqPausePush():void {
            var msg:PeerMsg = new PeerMsg();
            msg.msgSubType = PeerMsg.SUB_TYPE_PAUSE_PUSH;
            
            // we do not want any response from this request
            sendReq(msg, P2PSetting.MSG_TIMEOUT, true);
        }
        
        public function reqStopPush(externalID:String):void {
            var msg:PeerMsg = new PeerMsg();
            msg.msgSubType = PeerMsg.SUB_TYPE_STOP_PUSH;
            msg.obj["externalID"] = externalID;
            
            sendReq(msg, P2PSetting.MSG_TIMEOUT);
        }
        
        public function reqResumePush(uri:String):void {
            var msg:PeerMsg = new PeerMsg();
            msg.msgSubType = PeerMsg.SUB_TYPE_RESUME_PUSH;
            msg.obj["uri"] = uri;
            
            // we do not want any response from this request
            sendReq(msg, P2PSetting.MSG_TIMEOUT, true);
        }
        
        public function reqGoPush2(uri:String, chunkOffset:int, chunkLen:int,
                                pieceId:int, pieceCount:int,
                                externalID:String):void {
            var msg:PeerMsg = new PeerMsg();
            msg.msgSubType = PeerMsg.SUB_TYPE_GO_PUSH_MODE2;
            msg.obj["uri"] = uri;
            msg.obj["id"] = pieceId;
            msg.obj["count"] = pieceCount;
            msg.obj["chunkOffset"] = chunkOffset;
            msg.obj["chunkLen"] = chunkLen;
            msg.obj["externalID"] = externalID;
            
            sendReq(msg, P2PSetting.MSG_TIMEOUT);
        }
        
        public function respGoPush(req:PeerMsg, result:Boolean):void {
            var msg:PeerMsg = new PeerMsg();
            msg.msgSubType = PeerMsg.SUB_TYPE_GO_PUSH_MODE;
            msg.obj["result"] = result;
            
            sendResp(msg, req, P2PSetting.MSG_TIMEOUT, true);
        }
        
        public function respStopPush(req:PeerMsg):void {
            var msg:PeerMsg = new PeerMsg();
            msg.msgSubType = PeerMsg.SUB_TYPE_STOP_PUSH;
            msg.obj["externalID"] = req.obj["externalID"];
            
            sendResp(msg, req, P2PSetting.MSG_TIMEOUT);
        }
        
        public function respGoPush2(req:PeerMsg, result:Boolean):void {
            var msg:PeerMsg = new PeerMsg();
            msg.msgSubType = PeerMsg.SUB_TYPE_GO_PUSH_MODE2;
            msg.obj["result"] = result;
            msg.obj["externalID"] = req.obj["externalID"];
            
            sendResp(msg, req, P2PSetting.MSG_TIMEOUT, false);
        }
        
        public function get reqStatus():PeerReqStatus {
            return reqStatus_;
        }
        
        public function get respStatus():PeerRespStatus {
            return respStatus_;
        }
        
        public function get speedTestResult():int {
            return speedTestResult_;
        }
        
        public function set speedTestResult(val:int):void {
            speedTestResult_ = val;
        }
        
        public function get msgHooker():IPeerMsgHook {
            return msgHooker_;
        }
        
        public function set msgHooker(val:IPeerMsgHook):void {
            msgHooker_ = val;
        }
        
        public function get respWndMsgSize():int {
            return outRespWnd_.length;
        }
        
        public function get respWndPieceMsgSize():int {
            var ret:int = 0;
            for (var i:int = 0; i < outRespWnd_.length; i++) {
                if (outRespWnd_[i].isPieceMsg()) {
                    ret++;
                }
            }
            
            return ret;
        }
        
        public function get canBeRemoved():Boolean {
            var now:int = getTimer();
            
            if (connectFinishTime != -1) {
                if (now - connectFinishTime > 30) {
                    if (reqStatus_.canBeRemoved && respStatus_.canBeRemoved) {
                        return true;
                    }
                }
            }
            
            return false;
        }
        
        override public function toString():String {
            var desc:String = "";
            
            desc += "id=" + id_ + " outReqWnd_.length=" + outReqWnd_.length
                    + " outRespWnd_.length=" + outRespWnd_.length +
                    " reqStatus: " + reqStatus_.toString() +
                    " respStatus: " + respStatus_.toString()
                    ;
            
            return desc;
        }
        
        public function get normalClose():Boolean {
            return normalClose_;
        }
        
        public function set normalClose(val:Boolean):void {
            normalClose_ = val;
        }
                
        private var session_:RtmfpSession;
        private var id_:String;
        private var publishPoint_:PublishPoint;
        
        // remote publish point subscriber
        private var remotePubSub_:Subscriber = null;
        private var remotePriSub_:Subscriber = null;
        private var localPubPPConnected_:Boolean;
        private var localPriPublishPoint_:PublishPoint = null;
        private var msgId:int = 0;
        
        private var outReqWnd_:Vector.<PeerMsg> = new Vector.<PeerMsg>();
        private var outRespWnd_:Vector.<PeerMsg> = new Vector.<PeerMsg>();
        private var canSendReq_:Boolean = true;
        private var canSendResp_:Boolean = true;
        
        private var connectTimer_:Timer = null;
        
        private var reqError_:Boolean = false;
        private var reqErrorCode_:String;
        private var reqErrorTime_:Date;
        
        private var respError_:Boolean = false;
        private var respErrorCode_:String;
        private var respErrorTime_:Date;
        
        public var pendingReq:PeerMsg = null;
        
        private var reqStatus_:PeerReqStatus = new PeerReqStatus();
        private var respStatus_:PeerRespStatus = new PeerRespStatus();
        
        private var speedTestResult_:int = -1;
        
        private var msgHooker_:IPeerMsgHook = null;
        
        public var connectStartTime:int = -1;
        public var connectFinishTime:int = -1;
        private var p2pNetwork_:P2PNetworkBase;
        
        private var normalClose_:Boolean = false;
        
        public var getPieceRespReceived:Boolean = false;
        
        public var statistics:PeerStatistics = new PeerStatistics();
    }

}