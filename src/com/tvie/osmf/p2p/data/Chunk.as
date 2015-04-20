package com.tvie.osmf.p2p.data 
{
    import com.tvie.osmf.p2p.peer.Peer;
    import flash.utils.ByteArray;
	/**
     * ...
     * @author dista
     */
    public class Chunk 
    {
        private static var CHUNK_IDX:Number = 0;
        public function Chunk(uri:String) 
        {
            uri_ = uri;
            idx_ = CHUNK_IDX;
            state_ = ChunkState.INIT;
            CHUNK_IDX++;
        }
        
        public function get uri():String {
            return uri_;
        }
        
        public function get state():String {
            return state_;
        }
        
        public function set state(val:String):void {
            state_ = val;
        }
        
        public function isOlder(another:Chunk):Boolean {
            if (another == this) {
                throw new ArgumentError("chunk identical");
            }
            
            if (idx_ < another.idx_) {
                return true;
            }
            
            return false;
        }
        
        public function get pieceCount():int {
            return pieceCount_;
        }
        
        public function removeNullPiece():void {
            for (var i:int = pieces_.length - 1; i >= 0; i--) {
                if (!pieces_[i].content) {
                    pieces_.splice(i, 1);
                }
            }
        }
        
        public function set pieceCount(val:int):void {
            pieceCount_ = val;
            
            pieces_.splice(0, pieces_.length);
            
            for (var i:int = 0; i < pieceCount_; i++) {
                var piece:Piece = new Piece(i);
                pieces_.push(piece);
            }
        }
        
        public function isPieceReady(pieceID:int):Boolean {
            for (var i:int = 0; i < pieces_.length; i++) {
                if (pieces_[i].pieceID == pieceID && pieces_[i].isReady) {
                    return true;
                }
            }
            
            return false;
        }
        
        public function get isReady():Boolean {
            if (size_ == -1) {
                return false;
            }
            
            var totalPieceSize:int = 0;
            for (var i:int = 0; i < pieces_.length; i++) {
                if (!pieces_[i].isReady) {
                    return false;
                }
                
                totalPieceSize += pieces_[i].content.length;
            }
            
            return (totalPieceSize == size_);
        }
        
        public function get isFromStableSource():Boolean {
            return  isFromStableSource_;
        }
        
        public function set isFromStableSource(val:Boolean):void {
            isFromStableSource_ = val;
        }
        
        public function get isError():Boolean {
            return isError_;
        }
        
        public function set isError(val:Boolean):void {
            isError_ = val;
        }
        
        public function get pieces():Vector.<Piece> {
            return pieces_;
        }
        
        public function get size():int {
            return size_;
        }
        
        public function calSize():void {
            size_ = 0;
            for (var i:int = 0; i < pieces_.length; i++)
            {
                size_ += pieces_[i].content.length;
            }
        }
        
        public function set size(val:int):void {
            size_ = val;
        }
        
        public function get idx():Number {
            return idx_;
        }
        
        public function addPiece(piece:Piece):Boolean {
            var lastPiece:Piece = null;
            var alreadyHas:Boolean = false;
            for (var i:int = 0; i < pieces_.length; i++) {
                var p:Piece = pieces_[i];
                
                // already has the piece, ignore it
                if (p.pieceID == piece.pieceID) {
                    alreadyHas = true;
                    break;
                }
                
                if (lastPiece == null && p.pieceID > piece.pieceID) {
                    pieces_.splice(i, 0, piece);
                    return true;
                }
                
                if (lastPiece != null && (lastPiece.pieceID < piece.pieceID)
                    && (piece.pieceID < p.pieceID)) {
                    pieces_.splice(i, 0, piece);
                    return true;
                }
                
                lastPiece = p;
            }
            
            if(!alreadyHas){
                pieces_.push(piece);
            }
            
            return !alreadyHas;
        }
        
        public function buildPiece(pieceID:int, pieceCount:int, offset:int, len:int):Piece {
            // pre-condition: the chunk is ready
            if (pieceID >= pieceCount) {
                throw new ArgumentError("pieceID > pieceCount");
            }
            
            var piece:Piece = null;
            
            piece = new Piece(pieceID);
            piece.content = getPieceData(offset, len);

            if (piece.content == null) {
                return null;
            }
            
            piece.chunkOffset = offset;
                        
            return piece;
        }
        
        /* *
         * @param offset: offset of chunk, if offset > chunk's length, return empty bytearray
         * @param len: len of the piece, if len == -1, it is the last piece, and get whatever data it has
         */
        public function getPieceData(offset:int, len:int):ByteArray {
            var po:int = 0;
            var ret:ByteArray = null;
            var oldLen:int = len;
            
            var ready:Boolean = isReady;
            
            if (len == -1 && !ready) {
                return null;
            }
            
            if (len == -1) {
                len = int.MAX_VALUE;
            }
            
            var start:int = 0;
            var pieceID:int = 0;
            for (var i:int = 0; i < pieces_.length; i++) {
                var piece:Piece = pieces_[i];
                if (piece.pieceID != pieceID) {
                    break;
                }
                start = 0;
                if (offset >= po) {
                    if (ret == null) {
                        ret = new ByteArray();
                    }
                    
                    start = offset - po;
                }
                
                if (len != -1 && ret != null) {
                    if (!piece.isReady) {
                        return null;
                    }
                    var left:int = len - ret.length;
                    var needRead:int = left;
                    
                    if (needRead > (piece.content.length - start)) {
                        needRead = piece.content.length - start;
                    }
                    
                    // no data to read
                    if (needRead > 0) {
                        piece.content.position = start;
                        piece.content.readBytes(ret, ret.length, needRead);
                        piece.content.position = 0;
                    }
                    
                    if (ret.length == len) {
                        break;
                    }
                }
                
                po += piece.content.length;
                pieceID++;
            }
            
            if (ret == null && ready) {
                return new ByteArray();
            }
            
            if (ret && oldLen != -1 && (oldLen != ret.length) && !ready) {
                return null;
            }
            
            return ret;
        }
        
        public function toString():String {
            var ret:String = "Chunk: uri=" + uri_ + " state=" + state_ + " idx=" + idx_
                    + " isFromStableSource=" + isFromStableSource_ + " size=" + size_
                    + " pieceCount=" + pieceCount + " isError=" + isError;
                    
            if (pieces.length > 0) {
                ret += " pieces: ";
                
                for (var i:int = 0; i < pieces_.length; i++) {
                    ret += " " + pieces_[i].toString();
                }
            }
            
            return ret;
        }
        
        public function get upstreamChunkAvgSize():int {
            return upstreamChunkAvgSize_;
        }
        
        public function set upstreamChunkAvgSize(val:int):void {
            upstreamChunkAvgSize_ = val;
        }
        
        private var uri_:String;
        private var idx_:Number;
        private var state_:String;
        private var pieces_:Vector.<Piece> = new Vector.<Piece>();
        private var pieceCount_:int = -1;
        private var isFromStableSource_:Boolean = false;
        private var size_:int = -1;
        private var isError_:Boolean = false;
        private var upstreamChunkAvgSize_:int = -1;
        public var calFrom:int = -1;
    }

}