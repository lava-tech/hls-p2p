package com.tvie.osmf.p2p.source 
{
    import com.tvie.osmf.p2p.events.ContentServerEvent;
    import com.tvie.osmf.p2p.utils.P2PSetting;
    import com.tvie.osmf.p2p.utils.RemoteLogger;
    import flash.events.Event;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.URLRequest;
	import flash.net.URLStream;
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	import flash.utils.Timer;
	
	import org.osmf.events.HTTPStreamingEvent;
	import org.osmf.events.HTTPStreamingEventReason;
	import org.osmf.net.httpstreaming.flv.FLVTagScriptDataMode;
	import org.osmf.utils.OSMFSettings;
    import org.osmf.utils.URL;
    import org.osmf.logging.Log;
    import org.osmf.logging.Logger;
    
	/**
     * ...
     * @author dista
     */
    public class HttpContentServer extends ContentServer 
    {
        
        public function HttpContentServer(urlBase:String) 
        {
            super(urlBase);
            url_ = new URL(urlBase);
        }
        
        override public function get isOpen():Boolean
		{
			return _isOpen;
		}
        
        override public function get isComplete():Boolean
		{
			return _isComplete;
		}
        
        override public function get hasData():Boolean
		{
			return _hasData;
		}
        
        override public function get hasErrors():Boolean
		{
			return _hasErrors;
		}
        
        override public function get downloadDuration():Number
		{
			return _downloadDuration;
		}
        
        override public function get downloadBytesCount():Number
		{
			return _downloadBytesCount;
		}
        
        override public function get totalAvailableBytes():int {
            if (!isOpen)
			{
				return 0;
			}
			else
			{
				//return _savedBytes.bytesAvailable + _urlStream.bytesAvailable;
                return _savedBytes.bytesAvailable;
			}
        }
        
        override public function getBytes(numBytes:int = 0):IDataInput {
			if ( !isOpen || numBytes < 0)
			{
				return null;
			}
			
			if (numBytes == 0)
			{
				numBytes = 1;
			}
			
			var totalAvailableBytes:int = this.totalAvailableBytes;
			if (totalAvailableBytes == 0)
			{
				_hasData = false;
			}
            
			if (totalAvailableBytes < numBytes)
			{
				return null;
			}
            
            return _savedBytes;
			
            /*
			// use first the previous saved bytes and complete as needed
			// with bytes from the actual stream.
			if (_savedBytes.bytesAvailable)
			{
				var needed:int = numBytes - _savedBytes.bytesAvailable;
				if (needed > 0)
				{
					_urlStream.readBytes(_savedBytes, _savedBytes.length, needed);
				}
                
				return _savedBytes;
			}
			
			// make sure that the saved bytes buffer is empty 
			// and return the actual stream.
			_savedBytes.length = 0;
            //_urlStream.readBytes(_savedBytes);
			//return _savedBytes;
            return _urlStream;
            */
        }
        
        override public function clearSavedBytes():void {
			if(_savedBytes == null)
			{
				// called after dispose
				return;
			}
			_savedBytes.length = 0;
			_savedBytes.position = 0;
        }
        
        override public function appendToSavedBytes(source:IDataInput, count:uint):void {
			if(_savedBytes == null)
			{
				// called after dispose
				return;
			}
			source.readBytes(_savedBytes, _savedBytes.length, count);
        }
        
        override public function saveRemainingBytes():void {
			if(_savedBytes == null)
			{
				// called after dispose
				return;
			}
			if (_urlStream != null && _urlStream.connected && _urlStream.bytesAvailable)
			{
				_urlStream.readBytes(_savedBytes, _savedBytes.length);
			}
			else
			{
				// no remaining bytes
			}
        }
        
        override public function toString():String {
			// TODO : add request url to this string
			return "HTTPContentServer";
        }
        
        private function changeUrl(request:URLRequest):void {
            var re:RegExp = /(\w+):\/\/([^\/]+)/ ;
            var replaced:String = "$1://" + url_.host;
            if (url_.port) {
                replaced += ":" + url_.port;
            }
            
            request.url = request.url.replace(re, replaced);
        }
        
        override public function open2(request:Object, dispatcher:IEventDispatcher, timeout:Number, callerDispatcher:IEventDispatcher):void {
            _callerDispatcher = callerDispatcher;
            open(request, dispatcher, timeout);
        }
        
        override public function open(requestObj:Object, dispatcher:IEventDispatcher, timeout:Number):void
        {
            var request:URLRequest = requestObj as URLRequest;
            _requestUrl = request.url;
            
            changeUrl(request);
            
            if (isOpen || (_urlStream != null && _urlStream.connected))
				close();
			
			if(request == null)
			{
				throw new ArgumentError("Null request in HTTPStreamDownloader open method."); 
			}
			
			_isComplete = false;
			_hasData = false;
			_hasErrors = false;
			
			_dispatcher = dispatcher;
			if (_savedBytes == null)
			{
				_savedBytes = new ByteArray();
			}
			
			if (_urlStream == null)
			{
				_urlStream = new URLStream();
				_urlStream.addEventListener(Event.OPEN, onOpen);
				_urlStream.addEventListener(Event.COMPLETE, onComplete);
				_urlStream.addEventListener(ProgressEvent.PROGRESS, onProgress);
				_urlStream.addEventListener(IOErrorEvent.IO_ERROR, onError);
				_urlStream.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);
			}
			
			if (_timeoutTimer == null && timeout != -1)
			{
				_timeoutTimer = new Timer(timeout, 1);
				_timeoutTimer.addEventListener(TimerEvent.TIMER_COMPLETE, onTimeout);
			}
            
            if (_urlStream != null)
            {
                _timeoutInterval = timeout;
                _request = request;
                CONFIG::LOGGING
                {
                    logger.debug("Loading (timeout=" + _timeoutInterval + ", retry=" + _currentRetry + "):" + _request.url.toString());
                }
                
                _downloadBeginDate = null;
                _downloadBytesCount = 0;
                startTimeoutMonitor(_timeoutInterval);
                _urlStream.load(_request);
            }
        }
        
        override public function close(dispose:Boolean = false):void {
			stopTimeoutMonitor();

			_isOpen = false;
			_isComplete = false;
			_hasData = false;
			_hasErrors = false;
			_request = null;
			
			if (_timeoutTimer != null)
			{
				_timeoutTimer.stop();
				if (dispose)
				{
					_timeoutTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, onTimeout);
					_timeoutTimer = null;
				}
			}

			if (_urlStream != null)
			{
				if (_urlStream.connected)
				{
					_urlStream.close();
				}
				if (dispose)
				{
					_urlStream.removeEventListener(Event.OPEN, onOpen);
					_urlStream.removeEventListener(Event.COMPLETE, onComplete);
					_urlStream.removeEventListener(ProgressEvent.PROGRESS, onProgress);
					_urlStream.removeEventListener(IOErrorEvent.IO_ERROR, onError);
					_urlStream.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);
					_urlStream = null;
				}
			}

			if (_savedBytes != null)
			{
				_savedBytes.length = 0;
				if (dispose)
				{
					_savedBytes = null;
				}
			}
        }
        
        /// Event handlers
		/**
		 * @private
		 * Called when the connection has been open.
		 **/
		private function onOpen(event:Event):void
		{
			_isOpen = true;
		}
		
		/**
		 * @private
		 * Called when all data has been downloaded.
		 **/
		private function onComplete(event:Event):void
		{
			if (_downloadBeginDate == null)
			{
				_downloadBeginDate = new Date();
			}
			
			_downloadEndDate = new Date();
			_downloadDuration = (_downloadEndDate.valueOf() - _downloadBeginDate.valueOf())/1000.0;
			
			_isComplete = true;
			_hasErrors = false;
            
            DebugLogger.log("Download " + _request.url + " success");
			
			CONFIG::LOGGING
			{
				logger.debug("Loading complete. It took " + _downloadDuration + " sec and " + _currentRetry + " retries to download " + _downloadBytesCount + " bytes.");	
			}
            
            //_urlStream.readBytes(_savedBytes, _savedBytes.length, _urlStream.bytesAvailable);
            
            var completeEvent:ContentServerEvent = new ContentServerEvent(ContentServerEvent.STATUS);
            completeEvent.code = ContentServerEvent.COMPLETE;

            _callerDispatcher.dispatchEvent(completeEvent);
			
			if (_dispatcher != null)
			{
				var streamingEvent:HTTPStreamingEvent = new HTTPStreamingEvent(
					HTTPStreamingEvent.DOWNLOAD_COMPLETE,
					false, // bubbles
					false, // cancelable
					0, // fragment duration
					null, // scriptDataObject
					FLVTagScriptDataMode.NORMAL, // scriptDataMode
					_request.url, // urlString
					_downloadBytesCount, // bytesDownloaded
					HTTPStreamingEventReason.NORMAL, // reason
					null /*this*/); // downloader
				_dispatcher.dispatchEvent(streamingEvent);
			}
		}
		
		/**
		 * @private
		 * Called when additional data has been received.
		 **/
		private function onProgress(event:ProgressEvent):void
		{
			if (_downloadBeginDate == null)
			{
				_downloadBeginDate = new Date();
			}
			
			if (_downloadBytesCount == 0)
			{
				if (_timeoutTimer != null)
				{
					stopTimeoutMonitor();
				}
				_currentRetry = 0;

				_downloadBytesCount = event.bytesTotal;
				CONFIG::LOGGING
				{
					logger.debug("Loaded " + event.bytesLoaded + " bytes from " + _downloadBytesCount + " bytes.");
				}
			}
			
			_hasData = true;
            
            var progressEvent:ContentServerEvent = new ContentServerEvent(ContentServerEvent.STATUS);
            progressEvent.code = ContentServerEvent.PROGRESS;
            progressEvent.data = new ByteArray();
        
            _urlStream.readBytes(progressEvent.data, 0, _urlStream.bytesAvailable);
            progressEvent.data.readBytes(_savedBytes, _savedBytes.length, progressEvent.data.bytesAvailable);
            progressEvent.data.position = 0;
        
            _callerDispatcher.dispatchEvent(progressEvent);
			
			if(_dispatcher != null)
			{
				var streamingEvent:HTTPStreamingEvent = new HTTPStreamingEvent(
					HTTPStreamingEvent.DOWNLOAD_PROGRESS,
					false, // bubbles
					false, // cancelable
					0, // fragment duration
					null, // scriptDataObject
					FLVTagScriptDataMode.NORMAL, // scriptDataMode
					_request.url, // urlString
					0, // bytesDownloaded
					HTTPStreamingEventReason.NORMAL, // reason
					null /*this*/); // downloader
				_dispatcher.dispatchEvent(streamingEvent);
			}
				
		}	
		
		/**
		 * @private
		 * Called when an error occurred while downloading.
		 **/
		private function onError(event:Event):void
		{
			if (_timeoutTimer != null)
			{
				stopTimeoutMonitor();
			}
			
			if (_downloadBeginDate == null)
			{
				_downloadBeginDate = new Date();
			}
			_downloadEndDate = new Date();
			_downloadDuration = (_downloadEndDate.valueOf() - _downloadBeginDate.valueOf()) / 1000.0;

			_isComplete = false;
			_hasErrors = true;

			CONFIG::LOGGING
			{
				logger.error("Loading failed. It took " + _downloadDuration + " sec and " + _currentRetry + " retries to fail while downloading [" + _requestUrl + "].");
				logger.error("URLStream error event: " + event);
			}
            	
            var reason:String = HTTPStreamingEventReason.NORMAL;
            if(event.type == Event.CANCEL)
            {
                reason = HTTPStreamingEventReason.TIMEOUT;
            }
                
            var errorEvent:ContentServerEvent = new ContentServerEvent(ContentServerEvent.STATUS);
            errorEvent.code = ContentServerEvent.ERROR;
            errorEvent.url = _requestUrl;
            errorEvent.reason = reason;
            _callerDispatcher.dispatchEvent(errorEvent);
            
			if (_dispatcher != null)
			{
				var streamingEvent:HTTPStreamingEvent = new HTTPStreamingEvent(
					HTTPStreamingEvent.DOWNLOAD_ERROR,
					false, // bubbles
					false, // cancelable
					0, // fragment duration
					null, // scriptDataObject
					FLVTagScriptDataMode.NORMAL, // scriptDataMode
					_requestUrl, // urlString
					0, // bytesDownloaded
					reason, // reason
					null /*this*/); // downloader
				_dispatcher.dispatchEvent(streamingEvent);
			}
		}
		
		/**
		 * @private
		 * Starts the timeout monitor.
		 */
		private function startTimeoutMonitor(timeout:Number):void
		{
			if (_timeoutTimer != null)
			{
				if (timeout > 0)
				{
					_timeoutTimer.delay = timeout;
				}
				_timeoutTimer.reset();
				_timeoutTimer.start();
			}
		}
		
		/**
		 * @private
		 * Stops the timeout monitor.
		 */
		private function stopTimeoutMonitor():void
		{
			if (_timeoutTimer != null)
			{
				_timeoutTimer.stop();
			}
		}
		
		/**
		 * @private
		 * Event handler called when no data was received but the timeout interval passed.
		 */ 
		private function onTimeout(event:TimerEvent):void
		{
            DebugLogger.log("HttpContentServer onTimeout");
			CONFIG::LOGGING
			{
				logger.error("Timeout while trying to download [" + _request.url + "]");
				logger.error("Canceling and retrying the download.");
			}
            
			if (OSMFSettings.hdsMaximumRetries > -1)
			{
				_currentRetry++;
			}
			
			if (	
					OSMFSettings.hdsMaximumRetries == -1 
				||  (OSMFSettings.hdsMaximumRetries != -1 && _currentRetry < OSMFSettings.hdsMaximumRetries)
			)
			{					
				open(_request, _dispatcher, _timeoutInterval + OSMFSettings.hdsTimeoutAdjustmentOnRetry);
			}
			else
			{
				close();
				onError(new Event(Event.CANCEL));
			}
		}
        
        private var _isOpen:Boolean = false;
		private var _isComplete:Boolean = false;
		private var _hasData:Boolean = false;
		private var _hasErrors:Boolean = false;
		private var _savedBytes:ByteArray = null;
		private var _urlStream:URLStream = null;
		private var _request:URLRequest = null;
		private var _dispatcher:IEventDispatcher = null;
        private var _callerDispatcher:IEventDispatcher = null;
		
		private var _downloadBeginDate:Date = null;
		private var _downloadEndDate:Date = null;
		private var _downloadDuration:Number = 0;
		private var _downloadBytesCount:Number = 0;
		
		private var _timeoutTimer:Timer = null;
		private var _timeoutInterval:Number = 1000;
		private var _currentRetry:Number = 0;
        
        private var url_:org.osmf.utils.URL;
        private var _requestUrl:String;

        CONFIG::LOGGING
		{
			private static const logger:Logger = Log.getLogger("com.tvie.osmf.p2p.source.HttpContentServer") as Logger;
		}
    }

}