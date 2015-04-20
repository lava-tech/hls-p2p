package com.tvie.osmf.p2p.peer 
{
    import com.tvie.osmf.p2p.data.Chunk;
	/**
     * ...
     * @author dista
     */
    public class PeerRespStatus extends PeerStatus
    {
        
        public function PeerRespStatus() 
        {
            
        }
        
        public function toString():String {
            var desc:String = "goPushUri=" + goPushUri + " goPushPieceID=" + goPushPieceID
                            + " goPushPieceCount=" + goPushPieceCount + " goPushChunkOffset=" + goPushChunkOffset
                            + " goPushChunkLen=" + goPushChunkLen + " goPushIdx=" + goPushIdx
                            + " goPushResult=" + goPushResult + " pushResumeUri=" + pushResumeUri
                            + " lastPushPieceSize=" + lastPushPieceSize + " lastPushPieceUsedTime" + lastPushPieceUsedTime
                            + " lastPushPieceSendTime=" + lastPushPieceSendTime + " lastPushPieceId=" + lastPushPieceId;
            
            return desc;
        }
        
        public function addToPendingPushChunks(chunk:Chunk):void {
            if (goPushChunks.length == 0) {
                goPushChunks.push(chunk);
                return;
            }
            
            // make sure it will not added twice
            for (var j:int = 0; j < goPushChunks.length; j++) {
                if (goPushChunks[i].idx == chunk.idx) {
                    return;
                }
            }
            
            var i:int;
            for (i = 0; i < goPushChunks.length; i++) {
                if (!goPushChunks[i].isOlder(chunk)) {
                    break;
                }
            }
            
            goPushChunks.splice(i, 0, chunk);
        }
        
        public var goPushUri:String;
        public var goPushPieceID:int;
        public var goPushPieceCount:int;
        public var goPushChunkOffset:int;
        public var goPushChunkLen:int;
        public var goPushIdx:Number = -1;
        public var goPushChunks:Vector.<Chunk> = new Vector.<Chunk>();
        public var goPushResult:Boolean;
        public var pushResumeUri:String;
        public var lastPushPieceSize:int = -1;
        public var lastPushPieceUsedTime:int = -1;
        public var lastPushPieceSendTime:Number;
        public var lastPushPieceId:int;
        
        // there are some delay between sending goPush cmd and receive goPush confirm
        public var pushStateChangeDelayHandled:Boolean = false;
    }

}