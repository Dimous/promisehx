/**
    @author sebavan
    @author deltakosh

    Port of https://github.com/BabylonJS/Babylon.js/blob/master/src/Misc/promise.ts
**/

package io.github.dimous.util;

import haxe.Timer;
import haxe.Exception;

enum EPromiseState {
    PENDING;
    REJECTED;
    FULFILLED;
}
//---

class FulfillmentAggregator<T> {
    public var count: Int;
    public var target: Int;
    public final results: Array<Any>;
    public var rootPromise: Null<Promise<T>>;

    public function new() {
        this.count = 0;
        this.target = 0;
        this.results = [];
        this.rootPromise = null;
    }
}
//---

class Promise<T> {
    private var _reason: Any;
    private var _resultValue: Null<T>;
    private var _state: EPromiseState;
    private var _rejectWasConsumed: Bool;
    private var _parent: Null<Promise<T>>;
    private var _result(get, set): Null<T>;
    private var _children: Array<Promise<T>>;
    private var _onRejected: (reason: Any) -> Void;
    private var _onFulfilled: (fulfillment: Null<T>) -> Null<Promise<T>>;

    public function new(?resolver: (resolve: (?value: Null<T>) -> Void, reject: (resaon: Any) -> Void) -> Void) {
        this._children = [];
        this._rejectWasConsumed = false;
        this._state = EPromiseState.PENDING;

        if (null != resolver) {
            try {
                resolver(
                    (?value: Null<T>) -> {
                        this._resolve(value);
                    },
                    (reason: Any) -> {
                        this._reject(reason);
                    }
                );
            } catch (exception: Exception) {
                this._reject(exception);
            }
        }
    }
    //---

    public function catchError(onRejected: (reason: Any) -> Void): Promise<T> return this.then(null, onRejected);
    //---

    public function then(?onFulfilled: (?fulfillment: Null<T>) -> Null<Promise<T>>, ?onRejected: (reason: Any) -> Void): Promise<T> {
        final promise = new Promise<T>();

        promise._onRejected = onRejected;
        promise._onFulfilled = onFulfilled;

        this._children.push(promise);

        promise._parent = this;

        if (EPromiseState.PENDING != this._state) {
            Timer.delay(
                () -> {
                    if (EPromiseState.FULFILLED == this._state || this._rejectWasConsumed) {
                        promise._resolve(this._result);
                    } else {
                        promise._reject(this._reason);
                    }
                },
            0);
        }

        return promise;
    }
    //---

    public static function resolve<T>(value: T): Promise<T> {
        final promise = new Promise<T>();

        promise._resolve(value);
        
        return promise;
    }
    //---

    public static function all<T>(promises: Array<Promise<T>>): Promise<Array<T>> {
        final length = promises.length;
        final promise = new Promise<Array<T>>();
        final aggregator = new FulfillmentAggregator<Array<T>>();

        aggregator.target = length;
        aggregator.rootPromise = promise;

        if (0 < length) {
            for (index in 0...length) {
                Promise._registerForFulfillment(promises[index], aggregator, index);
            }
        } else {
            promise._resolve([]);
        }

        return promise;
    }
    //---

    public static function race<T>(promises: Array<Promise<T>>): Promise<T> {
        var newPromise = new Promise<T>();

        if (0 < promises.length) {
            for (promise in promises) {
                promise.then(
                    (?value: Null<T>) -> {
                        if (null != newPromise) {
                            newPromise._resolve(value);
                            newPromise = null;
                        }

                        return null;
                    },
                    (reason: Any) -> {
                        if (null != newPromise) {
                            newPromise._reject(reason);
                            newPromise = null;
                        }
                    }
                );
            }
        }

        return newPromise;
    }
    //---

    private function get__result(): Null<T> return this._resultValue;

    private function set__result(value: Null<T>) {
        this._resultValue = value;

        if (null != this._parent && null == this._parent._result) {
            this._parent._result = value;
        }

        return value;
    }
    //---

    private function _resolve(?value: Null<T>): Void {
        try {
            var promise = null;
            
            this._state = EPromiseState.FULFILLED;

            if (null != this._onFulfilled) {
                promise = this._onFulfilled(value);
            }

            if (null != promise) {
                if (null != promise._state) {
                    promise._parent = this;
                    promise._moveChildren(this._children);

                    value = promise._result;
                } else {
                    value = cast promise;
                }
            }

            this._result = value;

            for (child in this._children) {
                child._resolve(value);
            }

            this._children.resize(0);

            this._onRejected = null;
            this._onFulfilled = null;
        } catch (exception: Exception) {
            this._reject(exception, true);
        }
    }
    //---

    private function _reject(reason: Any, onLocalThrow: Bool = false): Void {
        this._reason = reason;
        this._state = EPromiseState.REJECTED;

        if (null != this._onRejected && !onLocalThrow) {
            try {
                this._onRejected(reason);
                this._rejectWasConsumed = true;
            } catch (exception: Exception) {
                reason = exception;
            }
        }

        for (child in this._children) {
            if (this._rejectWasConsumed) {
                child._resolve(null);
            } else {
                child._reject(reason);
            }
        }

        this._children.resize(0);

        this._onRejected = null;        
        this._onFulfilled = null;
    }
    //---

    private function _moveChildren(children: Array<Promise<T>>): Void {
        this._children = this._children.concat(children.copy());
        
        for (child in this._children) {
            child._parent = this;
            
            if (EPromiseState.FULFILLED == this._state) {
                child._resolve(this._result);
            } else
                if (EPromiseState.REJECTED == this._state) {
                    child._reject(this._reason);
                }
        }
    }
    //---

    private static function _registerForFulfillment<T>(promise: Promise<T>, aggregator: FulfillmentAggregator<Array<T>>, index: Int) {
        promise.then(
            (?value: Null<T>) -> {
                aggregator.results[index] = value;
                aggregator.count ++;

                if (aggregator.count == aggregator.target) {
                    aggregator.rootPromise._resolve(cast aggregator.results);
                }

                return null;
            },
            (reason: Any) -> {
                if (EPromiseState.REJECTED != aggregator.rootPromise._state) {
                    aggregator.rootPromise._reject(reason);
                }
            }
        );
    }
}
