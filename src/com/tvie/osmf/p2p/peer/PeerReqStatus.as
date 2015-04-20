package com.tvie.osmf.p2p.peer 
{
	/**
     * ...
     * @author dista
     */
    public class PeerReqStatus extends PeerStatus
    {
        
        public function PeerReqStatus() 
        {
            
        }
        
        public function get isUsed():Boolean {
            return isUsed_;
        }
        
        public function set isUsed(val:Boolean):void {
            isUsed_ = val;
        }
        
        public function get willBeUsed():Boolean {
            return willBeUsed_;
        }
        
        public function set willBeUsed(val:Boolean):void {
            willBeUsed_ = val;
        }
        
        public function get pieceNumber():int {
            return pieceNumber_;
        }
        
        public function set pieceNumber(val:int):void {
            pieceNumber_ = val;
        }
        
        public function get hasChunkFinished():Boolean {
            return hasChunkFinished_;
        }
        
        public function set hasChunkFinished(val:Boolean):void {
            hasChunkFinished_ = val;
        }
        
        public function set hasChunkReqIdx(val:int):void {
            hasChunkReqIdx_ = val;
        }
        
        public function get hasChunkReqIdx():int {
            return hasChunkReqIdx_;
        }
        
        public function get lastReqHasError():Boolean {
            return lastReqHasError_;
        }
        
        public function set lastReqHasError(val:Boolean):void {
            lastReqHasError_ = val;
        }
        
        public function get pushPieceID():int {
            return pushPieceID_;
        }
        
        public function set pushPieceID(val:int):void {
            pushPieceID_ = val;
        }
        
        public function get lastPingId():int {
            return lastPingId_;
        }
        
        public function set lastPingId(val:int):void {
            lastPingId_ = val;
        }
        
        public function get pushChunkOffset():int {
            return pushChunkOffset_;
        }
        
        public function set pushChunkOffset(val:int):void {
            pushChunkOffset_ = val;
        }
        
        public function get pushChunkLen():int {
            return pushChunkLen_;
        }
        
        public function set pushChunkLen(val:int):void {
            pushChunkLen_ = val;
        }
        
        public function get pushPieceCount():int {
            return pushPieceCount_;
        }
        
        public function set pushPieceCount(val:int):void {
            pushPieceCount_ = val;
        }
        
        public function set lastPushPieceUsedTime(val:Number):void {
            lastPushPieceUsedTime_ = val;
        }
        
        public function get lastPushPieceUsedTime():Number {
            return lastPushPieceUsedTime_;
        }
        
        public function toString():String {
            var desc:String = "isUsed_=" + isUsed_ + " pieceNumber_=" + pieceNumber_
                            + " hasChunkFinished_=" + hasChunkFinished_ +
                            " hasChunkReqIdx_="
                            + hasChunkReqIdx_ + " lastReqHasError_=" + lastReqHasError_
                            + " lastPingId_=" + lastPingId_ + " pushPieceID_=" + pushPieceID_
                            + " pushPieceCount_=" + pushPieceCount_ + " pushChunkOffset_=" + pushChunkOffset_
                            + " pushChunkLen_=" + pushChunkLen_;
            
            return desc;
        }
        
        public function get closeSent():Boolean {
            return closeSent_;
        }
        
        public function set closeSent(val:Boolean):void {
            closeSent_ = val;
        }
        
        public function setChunkInfo(pieceID:int, pieceCount:int, chunkSize:int):void
        {
            pushPieceID = pieceID;
            pushPieceCount = pieceCount;

            var pieceSize:int = Math.floor(chunkSize / pushPieceCount);
            pushChunkOffset = pieceSize * pushPieceID;
            
            if (pushPieceCount == (pushPieceID + 1)) {
                // last piece
                pushChunkLen = -1;
            }
            else {
                pushChunkLen = pieceSize;
            }
        }

        private var isUsed_:Boolean = false;
        private var willBeUsed_:Boolean = false;
        private var pieceNumber_:int = -1;
        private var hasChunkFinished_:Boolean = false;
        private var hasChunkReqIdx_:int = -1;
        private var lastReqHasError_:Boolean = false;
        
        private var lastPingId_:int = 0;
        
        private var pushPieceID_:int = -1;
        private var pushPieceCount_:int = -1;
        private var pushChunkOffset_:int = -1;
        private var pushChunkLen_:int = -1;
        private var closeSent_:Boolean = false;
        
        private var lastPushPieceUsedTime_:Number = -1;
    }

}