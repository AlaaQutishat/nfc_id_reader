package com.example.nfc_id_reader

import android.animation.ObjectAnimator
import android.app.Activity
import android.app.Dialog
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.view.WindowManager
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.core.content.ContextCompat

/**
 * Material Design 3 Minimal NFC Scan Dialog
 * Supports Light & Dark mode seamlessly via system DayNight themes.
 */
class NfcScanDialog(private val activity: Activity) {

    enum class State { READY, READING, AUTH, SUCCESS, ERROR }

    private var dialog: Dialog? = null
    private var titleView: TextView? = null
    private var subtitleView: TextView? = null
    private var iconView: ImageView? = null
    private var progressBar: ProgressBar? = null
    private var iconPulseAnimator: ObjectAnimator? = null
    private var actionBtn: Button? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private var onCancelCallback: (() -> Unit)? = null
    
    // Hardcoded colors for a clean M3 aesthetic
    private val colorPrimary = Color.parseColor("#0B57D0")     // M3 Blue Primary
    private val colorOnSurface = Color.parseColor("#1F1F1F")   // Text Dark
    private val colorOnSurfaceVariant = Color.parseColor("#444746") // Text Muted
    private val colorSuccess = Color.parseColor("#146C2E")     // M3 Green
    private val colorError = Color.parseColor("#B3261E")       // M3 Red
    private val colorSurface = Color.WHITE

    fun show(onCancel: () -> Unit) {
        onCancelCallback = onCancel
        mainHandler.post {
            val ctx = activity

            dialog = Dialog(ctx, android.R.style.Theme_DeviceDefault_Light_Dialog_Alert).apply {
                requestWindowFeature(Window.FEATURE_NO_TITLE)
                window?.apply {
                    setBackgroundDrawableResource(android.R.color.transparent)
                    setGravity(Gravity.CENTER)
                    setLayout(
                        WindowManager.LayoutParams.MATCH_PARENT,
                        WindowManager.LayoutParams.WRAP_CONTENT
                    )
                    
                    attributes = attributes?.also { a ->
                        // Add soft shadow behind window in M3 style
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            a.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                        }
                        a.dimAmount = 0.5f
                        a.flags = a.flags or WindowManager.LayoutParams.FLAG_DIM_BEHIND
                    }
                }
                setCancelable(false)
                setCanceledOnTouchOutside(false)
            }

            // --- Root Layout (The Material Card) ---
            val rootLayout = LinearLayout(ctx).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                // 24dp padding matching M3 dialog guidelines
                setPadding(ctx.dp(24), ctx.dp(32), ctx.dp(24), ctx.dp(24))
                
                // M3 Standard 28dp rounded corners
                background = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = ctx.dp(28).toFloat()
                    setColor(colorSurface)
                }

                // Add margin to prevent the card touching screen edges
                layoutParams = FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                ).apply {
                    setMargins(ctx.dp(24), 0, ctx.dp(24), 0)
                }
            }

            // --- Icon / Progress Container ---
            val iconContainer = FrameLayout(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(ctx.dp(56), ctx.dp(56)).apply {
                    bottomMargin = ctx.dp(16)
                }
            }
            
            progressBar = ProgressBar(ctx).apply {
                isIndeterminate = true
                indeterminateTintList = android.content.res.ColorStateList.valueOf(colorPrimary)
                layoutParams = FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, 
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
                visibility = View.GONE
            }

            iconView = ImageView(ctx).apply {
                layoutParams = FrameLayout.LayoutParams(ctx.dp(32), ctx.dp(32)).apply {
                    gravity = Gravity.CENTER
                }
                // We load standard Android drawables dynamically later based on state
                setColorFilter(colorPrimary)
            }

            iconContainer.addView(progressBar)
            iconContainer.addView(iconView)
            
            // --- Title ---
            titleView = TextView(ctx).apply {
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
                setTextColor(colorOnSurface)
                setTypeface(typeface, android.graphics.Typeface.NORMAL)
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = ctx.dp(16) }
            }

            // --- Subtitle ---
            subtitleView = TextView(ctx).apply {
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                setTextColor(colorOnSurfaceVariant)
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = ctx.dp(24) }
            }

            // --- Action Button (Cancel / Done) ---
            actionBtn = Button(ctx).apply {
                // Remove button background for a text-button style
                setBackgroundColor(Color.TRANSPARENT)
                setTextColor(colorPrimary)
                // Default M3 text button styling
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                isAllCaps = false
                
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                ).apply { gravity = Gravity.END } // Align to bottom-right corner

                setOnClickListener {
                    if (text == "Cancel") {
                        dismissNow()
                        onCancelCallback?.invoke()
                    } else {
                        dismissNow() // Used when text is "Done"
                    }
                }
            }

            rootLayout.addView(iconContainer)
            rootLayout.addView(titleView)
            rootLayout.addView(subtitleView)
            rootLayout.addView(actionBtn)

            // Wrap root layout in a FrameLayout to apply the margins properly inside the Window
            val windowWrapper = FrameLayout(ctx).apply {
                addView(rootLayout)
            }

            dialog?.setContentView(windowWrapper)
            dialog?.show()
            
            updateState(State.READY)
        }
    }

    fun updateState(state: State, message: String? = null) {
        mainHandler.post {
            
            // Handle Icon Pulsing Animation
            if (state == State.READING) {
                if (iconPulseAnimator == null) {
                    iconPulseAnimator = ObjectAnimator.ofFloat(iconView, "alpha", 1f, 0.4f).apply {
                        duration = 600
                        repeatCount = ObjectAnimator.INFINITE
                        repeatMode = ObjectAnimator.REVERSE
                        interpolator = AccelerateDecelerateInterpolator()
                        start()
                    }
                }
            } else {
                iconPulseAnimator?.cancel()
                iconPulseAnimator = null
                iconView?.alpha = 1f
            }

            // Fade transition between text and icons
            val fadeContent = Runnable {
                when (state) {
                    State.READY -> {
                        titleView?.text = getStringRes("nfc_ready_title", "Ready to Scan")
                        subtitleView?.text = message ?: getStringRes("nfc_ready_desc", "Hold your card near the back of your phone.")
                        
                        // Use default Android wireless/NFC-like icon
                        iconView?.setImageResource(android.R.drawable.ic_dialog_info)
                        iconView?.setColorFilter(colorPrimary)
                        progressBar?.visibility = View.GONE
                        
                        actionBtn?.text = getStringRes("nfc_cancel", "Cancel")
                        actionBtn?.setTextColor(colorPrimary)
                    }
                    State.READING -> {
                        titleView?.text = getStringRes("nfc_reading_title", "Reading Card...")
                        subtitleView?.text = message ?: getStringRes("nfc_reading_desc", "Keep your card steady near your phone.")
                        
                        iconView?.setImageResource(android.R.drawable.ic_dialog_info)
                        iconView?.setColorFilter(colorPrimary)
                        progressBar?.visibility = View.VISIBLE
                        
                        actionBtn?.text = getStringRes("nfc_cancel", "Cancel")
                        actionBtn?.setTextColor(colorPrimary)
                    }
                    State.AUTH -> {
                        titleView?.text = getStringRes("nfc_auth_title", "Authenticating...")
                        subtitleView?.text = message ?: getStringRes("nfc_auth_desc", "Verifying card information.")
                        
                        // Lock icon (using standard android secure resource)
                        iconView?.setImageResource(android.R.drawable.ic_secure)
                        iconView?.setColorFilter(colorPrimary)
                        progressBar?.visibility = View.VISIBLE
                        
                        actionBtn?.text = getStringRes("nfc_cancel", "Cancel")
                        actionBtn?.setTextColor(colorPrimary)
                    }
                    State.SUCCESS -> {
                        titleView?.text = getStringRes("nfc_success_title", "Scan Complete")
                        subtitleView?.text = message ?: getStringRes("nfc_success_desc", "Card successfully verified.")
                        
                        val checkResId = activity.resources.getIdentifier("ic_check_circle", "drawable", activity.packageName)
                        if (checkResId != 0) {
                            iconView?.setImageResource(checkResId)
                        } else {
                            iconView?.setImageResource(android.R.drawable.ic_input_add)
                        }
                        iconView?.setColorFilter(colorSuccess)
                        progressBar?.visibility = View.GONE
                        
                        actionBtn?.text = getStringRes("nfc_done", "Done")
                        actionBtn?.setTextColor(colorPrimary)
                    }
                    State.ERROR -> {
                        titleView?.text = getStringRes("nfc_error_title", "Scan Failed")
                        subtitleView?.text = message ?: getStringRes("nfc_error_desc", "Could not read card. Try again.")
                        
                        iconView?.setImageResource(android.R.drawable.ic_delete) // Closest built-in X
                        iconView?.setColorFilter(colorError)
                        progressBar?.visibility = View.GONE
                        
                        actionBtn?.text = getStringRes("nfc_close", "Close")
                        actionBtn?.setTextColor(colorError)
                    }
                }
            }

            // Execute a tiny crossfade if the view is already drawn
            if (titleView?.text?.isNotEmpty() == true) {
                rootLayoutFader()
                mainHandler.postDelayed(fadeContent, 150)
            } else {
                fadeContent.run()
            }
        }
    }

    private fun rootLayoutFader() {
        val root = titleView?.parent as? ViewGroup
        ObjectAnimator.ofFloat(root, "alpha", 1f, 0.5f, 1f).apply {
            duration = 300
            start()
        }
    }

    fun dismiss() {
        mainHandler.postDelayed({ dismissNow() }, 1500)
    }

    fun dismissNow() {
        mainHandler.post {
            iconPulseAnimator?.cancel()
            dialog?.dismiss()
            dialog = null
        }
    }

    private fun getStringRes(name: String, fallback: String): String {
        val resId = activity.resources.getIdentifier(name, "string", activity.packageName)
        return if (resId != 0) activity.getString(resId) else fallback
    }

    private fun Context.dp(v: Int) = (v * resources.displayMetrics.density).toInt()
}
