package com.tvie.osmf.p2p 
{
    import flash.errors.IllegalOperationError;
    import flash.events.EventDispatcher;
    import flash.events.IEventDispatcher;
    import flash.net.URLRequest;
    import flash.utils.ByteArray;
    import flash.utils.IDataInput;
	/**
     * ...
     * @author dista
     */
    public class Loader extends EventDispatcher
    {
        
        public function Loader() 
        {
            
        }
        
        public function get isOpen():Boolean
		{
			throw new IllegalOperationError("must override");
		}
        
        public function get isComplete():Boolean
		{
			throw new IllegalOperationError("must override");
		}
        
        public function get hasData():Boolean
		{
			throw new IllegalOperationError("must override");
		}
        
        public function get hasErrors():Boolean
		{
			throw new IllegalOperationError("must override");
		}
        
        public function get downloadDuration():Number
		{
			throw new IllegalOperationError("must override");
		}
        
        public function get downloadBytesCount():Number
		{
			throw new IllegalOperationError("must override");
		}
        
        public function get totalAvailableBytes():int {
            throw new IllegalOperationError("must override");
        }
        
        public function getBytes(numBytes:int = 0):IDataInput {
            throw new IllegalOperationError("must override");
        }
        
        public function clearSavedBytes():void {
            throw new IllegalOperationError("must override");
        }
        
        public function appendToSavedBytes(source:IDataInput, count:uint):void {
            throw new IllegalOperationError("must override");
        }
        
        public function saveRemainingBytes():void {
            throw new IllegalOperationError("must override");
        }
        
        public function open(request:Object, dispatcher:IEventDispatcher, timeout:Number):void
        {
            throw new IllegalOperationError("must override");
        }
        
        public function open2(request:Object, dispatcher:IEventDispatcher, timeout:Number, callerDispatcher:IEventDispatcher):void {
            throw new IllegalOperationError("must override");
        }
        
        public function close(dispose:Boolean = false):void {
            throw new IllegalOperationError("must override");
        }
        
        public function setIndexData(data:ByteArray):void {
            throw new IllegalOperationError("must override");
        }
        
        public function canGetIdx():Boolean {
            throw new IllegalOperationError("must override");
        }
        
        public function getIdx(request:URLRequest):void {
            throw new IllegalOperationError("must override");
        }
    }

}