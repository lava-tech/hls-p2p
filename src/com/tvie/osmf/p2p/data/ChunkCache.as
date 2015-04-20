package com.tvie.osmf.p2p.data 
{
    import com.tvie.osmf.p2p.utils.P2PSetting;
    import flash.utils.ByteArray;
    import flash.utils.getTimer;
    import org.osmf.utils.URL;
	/**
     * ...
     * @author dista
     */
    public class ChunkCache 
    {
        
        public function ChunkCache() 
        {
            
        }
        
        public function addChunk(chunk:Chunk):void {
            chunks_.push(chunk);
        }
        
        public function getAvgChunkSize():int {
            var count:int = 0;
            var size:int = 0;
            for (var i:int = 0; i < chunks_.length; i++) {
                if (chunks_[i].isReady) {
                    size += chunks_[i].size;
                    count += 1;
                }
            }
            
            if (count == 0) {
                return -1;
            }
            
            return size / count;
        }
        
        public function getReadyChunkCount():int {
            var count:int = 0;
            var size:int = 0;
            for (var i:int = 0; i < chunks_.length; i++) {
                if (chunks_[i].isReady) {
                    count += 1;
                }
            }
            
            return count;
        }
        
        public function findChunk(uri:String):Chunk {
            // find from end to start
            
            var uri1:URL = new URL(uri);
            
            for (var i:int = chunks_.length - 1; i >= 0; i--) {
                var uri2:URL = new URL(chunks_[i].uri);
                
                // only compare path
                if (uri1.path == uri2.path) {
                    return chunks_[i];
                }
            }
            
            return null;
        }
        
        public function findChunkByIdx(idx:int):Chunk {
            for (var i:int = chunks_.length - 1; i >= 0; i--) {
                if (idx == chunks_[i].idx) {
                    return chunks_[i];
                }
            }
            
            return null;
        }
        
        public function getNewestReadyChunk():Chunk {
            for (var i:int = chunks_.length - 1; i >= 0; i--) {
                if (chunks_[i].isReady) {
                    return chunks_[i];
                }
            }
            
            return null;
        }
        
        public function isNewestChunkReady():Boolean {
            if (chunks_.length > 0) {
                if (chunks_[chunks_.length - 1].isReady) {
                    return true;
                }
                
                return false;
            }
            else {
                return true;
            }
        }
        
        public function getHasChunkReqChunk(lastNumber:int):Chunk {
            var ret:Chunk = null;
            var count:int = 0;
            for (var i:int = chunks_.length - 1; i >= 0; i--) {
                if (!chunks_[i].isFromStableSource) {
                    ret = chunks_[i];
                    count++;
                }
                else {
                    if (count < lastNumber) {
                        break;
                    }
                }
                
                if (count == lastNumber) {
                    return ret;
                }
            }
            
            return null;
        }
        
        public function getChunksNewer(chunk:Chunk):Vector.<Chunk> {
            var ret:Vector.<Chunk> = new Vector.<Chunk>();
            
            var found:Boolean = false;
            for (var i:int = 0; i < chunks_.length; i++) {
                if (chunks_[i].uri == chunk.uri) {
                    found = true;
                    continue;
                }
                
                if (found) {
                    ret.push(chunks_[i]);
                }
            }
            
            return ret;
        }
        
        public function getChunksNewerByIdx(idx:Number):Vector.<Chunk> {
            var ret:Vector.<Chunk> = new Vector.<Chunk>();
            
            var found:Boolean = false;
            for (var i:int = 0; i < chunks_.length; i++) {
                if (chunks_[i].idx == idx) {
                    found = true;
                    continue;
                }
                
                if (found) {
                    ret.push(chunks_[i]);
                }
            }
            
            return ret;
        }
        
        public function removeOldest():void {
            if (chunks_.length > 0) {
                chunks_.splice(0, 1);
            }
        }
        
        public function get length():int {
            return chunks_.length;
        }
        
        public function get indexData():ByteArray {
            return indexData_;
        }
        
        public function set indexData(val:ByteArray):void {
            if (val == null) {
                return;    
            }
            
            var newSeqNum:int = parseMediaSequence(String(val));
            if (newSeqNum == -1) {
                throw new Error("hls manifest file must contain #EXT-X-MEDIA-SEQUENCE");
            }
            
            if (oldSeqNum_ != -1 && oldSeqNum_ > newSeqNum) {
                return;
            }
            
            oldSeqNum_ = newSeqNum;
            indexData_ = val;
            lastSetTimer_ = getTimer();
        }
        
        public function isIdxTooOld():Boolean {
            if (lastSetTimer_ == -1) {
                return true;
            }
            
            if ((getTimer() - lastSetTimer_) >= P2PSetting.CHUNK_DURATION) {
                return true;
            }
            
            return false;
        }
        
        private function parseMediaSequence(data:String):int {
           var mediaSeq:int = -1;
           
           var lines:Vector.<String> = Vector.<String>(String(data).split(/\r?\n/));
           
           for (var i:int = 0; i < lines.length; i++) {
               if (lines[i].indexOf("#EXT-X-MEDIA-SEQUENCE:") == 0) {
                  mediaSeq =  parseInt(lines[i].match(/(\d+)/)[1]);
                  break;
               }
           }
           
           return mediaSeq;
        }
        
        private var chunks_:Vector.<Chunk> = new Vector.<Chunk>();
        private var indexData_:ByteArray = null;
        private var oldSeqNum_:int = -1;
        private var lastSetTimer_:int = -1;
    }

}