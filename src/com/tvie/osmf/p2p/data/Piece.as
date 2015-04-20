package com.tvie.osmf.p2p.data 
{
    import flash.utils.ByteArray;
	/**
     * ...
     * @author dista
     */
    public class Piece 
    {
        /**
         * 
         * @param pieceID pieceID == -1 means it is a piece contains one chunk data
         */
        public function Piece(pieceID:int) 
        {
            pieceID_ = pieceID;
        }
        
        public function get isReady():Boolean {
            return isReady_;
        }
        
        public function set isReady(val:Boolean):void {
            isReady_ = val;
        }
        
        public function get contentLength():int {
            return contentLength_;
        }
        
        public function set contentLength(val:int):void {
            contentLength_ = val;
        }
        
        public function get chunkOffset():int {
            return chunkOffset_;
        }
        
        public function set chunkOffset(val:int):void {
            chunkOffset_ = val;
        }
        
        public function get content():ByteArray {
            return content_;
        }
        
        public function set content(val:ByteArray):void {
            content_ = val;
        }
        
        public function get pieceID():int {
            return pieceID_;
        }
        
        public function set pieceID(val:int):void {
            pieceID_ = val;
        }
        
        public function toString():String {
            var ret:String = "piece: isReady=" + isReady_ + " pieceID=" + pieceID_
                    + " chunkOffset=" + chunkOffset_;
                    
            if (content == null) {
                ret += " content=NULL";
            }
            else {
                ret += " content.length=" + content_.length;
            }
            
            return ret;
        }
        
        private var content_:ByteArray = null;
        private var pieceID_:int;
        private var isReady_:Boolean = false;
        private var contentLength_:int = -1;
        private var chunkOffset_:int = -1;
    }

}