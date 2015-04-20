package com.tvie.osmf.p2p.peer 
{
    import com.tvie.osmf.p2p.events.PeerMsgErrorEvent;
    import flash.events.EventDispatcher;
    import flash.events.TimerEvent;
    import flash.utils.ByteArray;
    import flash.utils.Timer;
    
    [Event(name = "PeerMsgError", type = "com.tvie.osmf.p2p.events.PeerMsgErrorEvent")]
    
	/**
     * ...
     * @author dista
     */
    public class PeerMsg extends EventDispatcher
    {
        
        public function PeerMsg(obj:Object = null) 
        {
            if (obj == null) {
                this.obj = new Object();
            }
            else{
                this.obj = obj;
            }
            
            if (!this.obj.hasOwnProperty(SUB_TYPE)) {
                this.obj[SUB_TYPE] = INTERNAL_SUB_TYPE;
            }
        }
        
        public function startSend(timeout:int):void {
            timer_ = new Timer(timeout, 1);
            timer_.addEventListener(TimerEvent.TIMER_COMPLETE, onSendTimerComplete);
            timer_.start();
        }
        
        public function endSend():void {
            if (timer_ != null) {
                timer_.stop();
            }
        }
        
        public function isPieceMsg():Boolean {
            if (obj.hasOwnProperty(SUB_TYPE) &&
                (obj[SUB_TYPE] == SUB_TYPE_GET_PIECE || obj[SUB_TYPE] == SUB_TYPE_PUSH_PIECE)) {
                return true;       
            }
            
            return false;
        }
        
        public function get msgType():String {
            if (!obj.hasOwnProperty(TYPE)) {
                throw new Error("no " + TYPE);
            }
            return obj[TYPE];
        }
        
        public function get msgSubType():String {
            if (!obj.hasOwnProperty(SUB_TYPE)) {
                throw new Error("no " + SUB_TYPE);
            }
            return obj[SUB_TYPE];
        }
        
        public function get hasMsgSubType():Boolean {
            if (!obj.hasOwnProperty(SUB_TYPE)) {
                return false;
            }
            
            return true;
        }
        
        public function set msgSubType(val:String):void {
            obj[SUB_TYPE] = val;
        }
        
        public function get msgID():int {
            if (!obj.hasOwnProperty(MSG_ID)) {
                throw new Error("no " + MSG_ID);
            }
            return obj[MSG_ID];
        }
        
        public function get reqMsgID():int {
            if (!obj.hasOwnProperty(REQ_MSG_ID)) {
                throw new Error("no " + REQ_MSG_ID);
            }
            return obj[REQ_MSG_ID];
        }
        
        public function get respMsgID():int {
            if (!obj.hasOwnProperty(RESP_MSG_ID)) {
                throw new Error("no " + RESP_MSG_ID);
            }
            return obj[RESP_MSG_ID];
        }
        
        public function get needConfirm():Boolean {
            if (!obj.hasOwnProperty(NEED_CONFIRM)) {
                return false;
            }
            
            return obj[NEED_CONFIRM];
        }
        
        public function set needConfirm(val:Boolean):void {
            obj[NEED_CONFIRM] = val;
        }
        
        public function get careConfirm():Boolean {
            if (!obj.hasOwnProperty(CARE_CONFIRM)) {
                return false;
            }
            
            return obj[CARE_CONFIRM];
        }
        
        public function set careConfirm(val:Boolean):void {
            obj[CARE_CONFIRM] = val;
        }
        
        public function get sendTimestamp():Date {
            if (!obj.hasOwnProperty(SEND_TIMESTAMP)) {
                throw new Error("no sendTimestamp");
            }
            
            return obj[SEND_TIMESTAMP];
        }
        
        public function set sendTimestamp(val:Date):void {
            obj[SEND_TIMESTAMP] = val;
        }
        
        public function get queueTimestamp():Date {
            if (!obj.hasOwnProperty(QUEUE_TIMESTAMP)) {
                throw new Error("no queueTimestamp");
            }
            
            return obj[QUEUE_TIMESTAMP];
        }
        
        public function set queueTimestamp(val:Date):void {
            obj[QUEUE_TIMESTAMP] = val;
        }
        
        private function onSendTimerComplete(event:TimerEvent):void {
            var e:PeerMsgErrorEvent = new PeerMsgErrorEvent(PeerMsgErrorEvent.ERROR);
            e.code = PeerMsgErrorEvent.TIMEOUT;
            e.msg = this;
            
            dispatchEvent(e);
        }
        
        public function get sendDelayTime():int {
            if (addSendingTimestamp_ && addQueueTimestamp_) {
                return sendTimestamp.getTime() - queueTimestamp.getTime();
            }
            
            return -1;
        }
        
        public function get addSendingTimestamp():Boolean {
            return addSendingTimestamp_;
        }
        
        public function set addSendingTimestamp(val:Boolean):void {
            addSendingTimestamp_ = val;
        }
        
        public function get addQueueTimestamp():Boolean {
            return addQueueTimestamp_;
        }
        
        public function set addQueueTimestamp(val:Boolean):void {
            addQueueTimestamp_ = val;
        }
        
        public function getMsgSize():int {
            if (obj.hasOwnProperty(TYPE) && 
                obj.hasOwnProperty(SUB_TYPE) &&
                msgType == RESP) {
                if (msgSubType == SUB_TYPE_GET_PIECE) {
                    return obj['content'].length;
                }
                else if (msgSubType == SUB_TYPE_PUSH_PIECE) {
                    return obj['data'].length;
                }
            }
            
            var bytes:ByteArray = new ByteArray();
            bytes.writeObject(obj);
            
            return bytes.length;
        }
        
        public static const TYPE:String = "__type";
        public static const REQ:String = "__req";
        public static const RESP:String = "__resp";
        public static const CONFIRM:String = "__confirm";
        
        public static const SUB_TYPE:String = "__subtype";
        public static const INTERNAL_SUB_TYPE:String = "__internal_subtype";
        
        public static const MSG_ID:String = "__msg_id";
        public static const REQ_MSG_ID:String = "__req_msg_id";
        public static const RESP_MSG_ID:String = "__resp_msg_id";
        public static const RESP_CONFIRM:String = "__resp_confirm";
        public static const NEED_CONFIRM:String = "__need_confirm";
        
        public static const CARE_CONFIRM:String = "__care_confirm";
        
        public static const SEND_TIMESTAMP:String = "__send_timestamp";
        public static const QUEUE_TIMESTAMP:String = "__queue_timestamp";
        
        public static const MSG_NAME:String = "cmdMsg";
        
        public var obj:Object;
        
        private var timer_:Timer = null;
                      
        public static const SUB_TYPE_HAS_CHUNK:String = "hasChunk";
        public static const SUB_TYPE_GET_PIECE:String = "getPiece";
        public static const SUB_TYPE_GO_PUSH_MODE:String = "goPushMode";
        public static const SUB_TYPE_GO_PUSH_MODE2:String = "goPushMode2";
        public static const SUB_TYPE_PAUSE_PUSH:String = "pausePush";
        public static const SUB_TYPE_RESUME_PUSH:String = "resumePush";
        public static const SUB_TYPE_PUSH_PIECE:String = "pushPiece";
        public static const SUB_TYPE_PUSH_PIECE_ERROR:String = "pushPieceError";
        public static const SUB_TYPE_PING:String = "ping";
        public static const SUB_TYPE_SPEED_TEST:String = "speedTest";
        public static const SUB_TYPE_CLOSE:String = "close";
        public static const SUB_TYPE_STOP_PUSH:String = "stopPush";
        
        private var addSendingTimestamp_:Boolean = false;
        private var addQueueTimestamp_:Boolean = false;
    }

}