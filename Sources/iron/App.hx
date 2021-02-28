package iron;

import haxe.Constraints.Function;

class App {

	#if arm_appwh
	public static inline function w(): Int { return arm.App.w(); }
	public static inline function h(): Int { return arm.App.h(); }
	public static inline function x(): Int { return arm.App.x(); }
	public static inline function y(): Int { return arm.App.y(); }
	#else
	public static inline function w(): Int { return kha.System.windowWidth(); }
	public static inline function h(): Int { return kha.System.windowHeight(); }
	public static inline function x(): Int { return 0; }
	public static inline function y(): Int { return 0; }
	#end

	static var traitCallbackCommands: Array<TraitCallbackCommand> = [];
	static var onResets: Array<Void->Void> = null;
	static var onEndFrames: Array<Void->Void> = null;
	static var traitInits: Array<Void->Void> = [];
	static var traitUpdates: Array<Void->Void> = [];
	static var traitLateUpdates: Array<Void->Void> = [];
	static var traitRenders: Array<kha.graphics4.Graphics->Void> = [];
	static var traitRenders2D: Array<kha.graphics2.Graphics->Void> = [];
	public static var framebuffer: kha.Framebuffer;
	public static var pauseUpdates = false;

	#if arm_debug
	static var startTime: Float;
	public static var updateTime: Float;
	public static var renderPathTime: Float;
	#end
	#if arm_resizable
	static var lastw = -1;
	static var lasth = -1;
	public static var onResize: Void->Void = null;
	#end

	public static function init(done: Void->Void) {
		new App(done);
	}

	function new(done: Void->Void) {
		done();
		kha.System.notifyOnFrames(render);
		kha.Scheduler.addTimeTask(update, 0, iron.system.Time.delta);
	}

	public static function reset() {
		traitInits = [];
		traitUpdates = [];
		traitLateUpdates = [];
		traitRenders = [];
		traitRenders2D = [];
		if (onResets != null) for (f in onResets) f();
	}

	static function update() {
		if (Scene.active == null || !Scene.active.ready) return;
		if (pauseUpdates) return;

		#if arm_debug
		startTime = kha.Scheduler.realTime();
		#end

		Scene.active.updateFrame();

		evalTraitCallbackCommands();

		for (traitInit in traitInits) { traitInit(); }
		traitInits.resize(0);

		for (traitUpdate in traitUpdates) { traitUpdate(); }
		for (traitLateUpdate in traitLateUpdates) { traitLateUpdate(); }

		if (onEndFrames != null) for (traitEndFrame in onEndFrames) traitEndFrame();

		#if arm_debug
		iron.object.Animation.endFrame();
		updateTime = kha.Scheduler.realTime() - startTime;
		#end

		#if arm_resizable
		// Rebuild projection on window resize
		if (lastw == -1) { lastw = App.w(); lasth = App.h(); }
		if (lastw != App.w() || lasth != App.h()) {
			if (onResize != null) onResize();
			else {
				if (Scene.active != null && Scene.active.camera != null) {
					Scene.active.camera.buildProjection();
				}
			}
		}
		lastw = App.w();
		lasth = App.h();
		#end
	}

	static function render(frames: Array<kha.Framebuffer>) {
		var frame = frames[0];
		framebuffer = frame;

		iron.system.Time.update();

		evalTraitCallbackCommands();

		if (Scene.active == null || !Scene.active.ready) {
			render2D(frame);
			return;
		}

		#if arm_debug
		startTime = kha.Scheduler.realTime();
		#end

		for (traitInit in traitInits) { traitInit(); }
		traitInits.resize(0);

		Scene.active.renderFrame(frame.g4);

		for (traitRender in traitRenders) { traitRender(frame.g4); }

		render2D(frame);

		#if arm_debug
		renderPathTime = kha.Scheduler.realTime() - startTime;
		#end
	}

	static function render2D(frame: kha.Framebuffer) {
		if (traitRenders2D.length > 0) {
			frame.g2.begin(false);
			for (traitRender2D in traitRenders2D) { traitRender2D(frame.g2); }
			frame.g2.end();
		}
	}

	// Hooks
	public static function notifyOnInit(f: Void->Void) {
		traitCallbackCommands.push({target: Init, add: true, callbackFunc: f});
	}

	public static function removeInit(f: Void->Void) {
		traitCallbackCommands.push({target: Init, add: false, callbackFunc: f});
	}

	public static function notifyOnUpdate(f: Void->Void) {
		traitCallbackCommands.push({target: Update, add: true, callbackFunc: f});
	}

	public static function removeUpdate(f: Void->Void) {
		traitCallbackCommands.push({target: Update, add: false, callbackFunc: f});
	}

	public static function notifyOnLateUpdate(f: Void->Void) {
		traitCallbackCommands.push({target: LateUpdate, add: true, callbackFunc: f});
	}

	public static function removeLateUpdate(f: Void->Void) {
		traitCallbackCommands.push({target: LateUpdate, add: false, callbackFunc: f});
	}

	public static function notifyOnRender(f: kha.graphics4.Graphics->Void) {
		traitCallbackCommands.push({target: Render, add: true, callbackFunc: f});
	}

	public static function removeRender(f: kha.graphics4.Graphics->Void) {
		traitCallbackCommands.push({target: Render, add: false, callbackFunc: f});
	}

	public static function notifyOnRender2D(f: kha.graphics2.Graphics->Void) {
		traitCallbackCommands.push({target: Render2D, add: true, callbackFunc: f});
	}

	public static function removeRender2D(f: kha.graphics2.Graphics->Void) {
		traitCallbackCommands.push({target: Render2D, add: false, callbackFunc: f});
	}

	public static function notifyOnReset(f: Void->Void) {
		if (onResets == null) onResets = [];
		traitCallbackCommands.push({target: Reset, add: false, callbackFunc: f});
	}

	public static function removeReset(f: Void->Void) {
		traitCallbackCommands.push({target: Reset, add: false, callbackFunc: f});
	}

	public static function notifyOnEndFrame(f: Void->Void) {
		if (onEndFrames == null) onEndFrames = [];
		traitCallbackCommands.push({target: EndFrame, add: true, callbackFunc: f});
	}

	public static function removeEndFrame(f: Void->Void) {
		traitCallbackCommands.push({target: EndFrame, add: false, callbackFunc: f});
	}

	static function evalTraitCallbackCommands() {
		for (traitCmd in traitCallbackCommands) {
			var targetArray: Null<Array<Function>> = cast switch (traitCmd.target) {
				case Init: traitInits;
				case Update: traitUpdates;
				case LateUpdate: traitLateUpdates;
				case EndFrame: onEndFrames;
				case Reset: onResets;
				case Render: cast traitRenders;
				case Render2D: cast traitRenders2D;
				default: null;
			}

			// Also happens if onEndFrame or onRenderReset are not initialized
			if (targetArray == null) continue;

			traitCmd.add ? targetArray.push(traitCmd.callbackFunc) : targetArray.remove(traitCmd.callbackFunc);
		}
		traitCallbackCommands.resize(0);
	}
}

/**
	Represents a task that describes how to change the trait callback arrays at
	the beginning of the next frame, before executing the callbacks. This
	ensures that the callback arrays are not modified while iterating over them.
**/
@:dox(hide)
@:structInit class TraitCallbackCommand {
	public final target: TraitCallbackTarget;
	/** true: add callback to the target, false: remove from the target **/
	public final add: Bool;
	public final callbackFunc: Function;
}

/**
	@see `iron.App.TraitCallbackCommand`
**/
@:dox(hide)
enum abstract TraitCallbackTarget(Int) {
	var Init;
	var Update;
	var LateUpdate;
	var EndFrame;
	var Reset;
	var Render;
	var Render2D;
}
