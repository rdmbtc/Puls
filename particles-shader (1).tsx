"use client"

import { useRef, useEffect, useCallback } from "react"

// ── SVG Shape ────────────────────────────────────────────
const SVG_PATH = `M478.468,45.482h-87.71c-10.003,0-18.111,8.108-18.111,18.111c0,9.993,8.108,18.1,18.111,18.1        h85.031v124.765h-48.522c-5.151,0-10.168,0.618-14.969,1.803c-3.286,0.793-6.47,1.854-9.529,3.152        c-22.643,9.57-38.57,32.018-38.57,58.113c0,5.522,2.472,10.467,6.387,13.784c3.152,2.689,7.253,4.316,11.723,4.316        c9.993,0,18.1-8.108,18.1-18.1c0-9.272,4.718-17.462,11.888-22.293c4.275-2.884,9.426-4.564,14.969-4.564h51.2        c4.131,0,8.087-0.752,11.744-2.122c12.712-4.77,21.788-17.049,21.788-31.41V79.015C512,60.523,496.959,45.482,478.468,45.482z         M490.212,206.026v34.521c-3.657,1.37-7.613,2.122-11.744,2.122h-51.2       c-5.542,0-10.693,1.679-14.969,4.564v-38.972c4.801-1.185,9.818-1.803,14.969-1.803h48.522v-24.065       C484.35,186.813,490.212,195.744,490.212,206.026z M404.48,45.482v36.211h-13.722c-10.003,0-18.111-8.108-18.111-18.1       c0-10.003,8.108-18.111,18.111-18.111H404.48z M402.77,211.413c-4.1,26.816-15.463,51.561-32.183,71.896       c-3.915-3.317-6.387-8.262-6.387-13.784C364.2,243.431,380.126,220.984,402.77,211.413z M464.442,366.153l-13.189-8.743l-13.189,8.743c-4.858,3.22-11.345-0.263-11.345-6.091V206.029         c0-6.72,5.448-12.168,12.168-12.168h24.733c6.72,0,12.168,5.448,12.168,12.168v154.033         C475.787,365.891,469.299,369.374,464.442,366.153z M109.23,211.413c-3.06-1.298-6.243-2.359-9.529-3.152c-4.801-1.185-9.818-1.803-14.969-1.803        H36.211V81.693h85.031c10.003,0,18.111-8.108,18.111-18.1c0-10.003-8.108-18.111-18.111-18.111h-87.71        C15.041,45.482,0,60.523,0,79.015v130.122c0,14.361,9.076,26.64,21.788,31.41c3.657,1.37,7.613,2.122,11.744,2.122h51.2        c5.542,0,10.693,1.679,14.969,4.564c7.17,4.832,11.888,13.021,11.888,22.293c0,9.993,8.107,18.1,18.1,18.1        c4.471,0,8.571-1.628,11.723-4.316c3.915-3.317,6.387-8.262,6.387-13.784C147.8,243.431,131.873,220.984,109.23,211.413z M99.701,208.261v38.972c-4.275-2.884-9.426-4.564-14.969-4.564h-51.2       c-4.131,0-8.087-0.752-11.744-2.122v-34.521c0-10.281,5.862-19.213,14.423-23.632v24.065h48.521       C89.883,206.458,94.9,207.076,99.701,208.261z M147.8,269.526c0,5.522-2.472,10.467-6.387,13.784c-16.72-20.336-28.083-45.081-32.183-71.896       C131.873,220.984,147.8,243.431,147.8,269.526z M121.242,81.693H107.52V45.482h13.722c10.003,0,18.111,8.108,18.111,18.111       C139.353,73.586,131.245,81.693,121.242,81.693z M47.558,366.153l13.189-8.743l13.189,8.743c4.858,3.22,11.345-0.263,11.345-6.091V206.029         c0-6.72-5.448-12.168-12.168-12.168H48.38c-6.72,0-12.168,5.448-12.168,12.168v154.033         C36.213,365.891,42.701,369.374,47.558,366.153z M390.057,27.166v161.883c0,64.86-46.08,118.965-107.283,131.379v78.222h-53.549v-78.222     c-61.203-12.414-107.283-66.519-107.283-131.379V27.166c0-5.707,4.636-10.343,10.353-10.343h247.408     C385.422,16.823,390.057,21.458,390.057,27.166z M390.057,27.176v161.872c0,64.86-46.08,118.965-107.283,131.379v78.222h-22.798V313.96     c0-5.176,3.51-9.644,8.504-11.003c56.918-15.492,98.779-67.542,98.779-129.362V27.166c0-5.707-4.636-10.343-10.353-10.343h22.798     C385.422,16.823,390.057,21.458,390.057,27.176z M378.575,387.336v78.106h-245.15v-78.106c0-5.711,4.625-10.336,10.326-10.336h224.499      C373.95,377,378.575,381.625,378.575,387.336z M378.577,387.335v78.113H354.81v-78.113c0-5.704-4.629-10.334-10.334-10.334h23.767      C373.948,377.001,378.577,381.631,378.577,387.335z M420.637,495.177H91.363c-5.707,0-10.334-4.626-10.334-10.334v-26.193       c0-5.707,4.627-10.334,10.334-10.334h329.273c5.707,0,10.334,4.626,10.334,10.334v26.193       C430.97,490.551,426.344,495.177,420.637,495.177z M430.969,458.648v26.196c0,5.704-4.629,10.334-10.334,10.334h-22.817       c5.704,0,10.334-4.629,10.334-10.334v-26.196c0-5.704-4.629-10.334-10.334-10.334h22.817       C426.339,448.315,430.969,452.944,430.969,458.648z M309.226,421.939H202.774c-4.268,0-7.726-3.459-7.726-7.726s3.459-7.726,7.726-7.726h106.453    c4.268,0,7.726,3.459,7.726,7.726S313.494,421.939,309.226,421.939z M302.966,127.505c0,25.94-21.026,46.966-46.966,46.966c-4.214,0-8.303-0.556-12.187-1.597    c20.027-5.378,34.769-23.653,34.769-45.369c0-21.716-14.742-39.992-34.769-45.369c3.884-1.04,7.974-1.597,12.187-1.597    C281.94,80.539,302.966,101.565,302.966,127.505z M475.789,206.026v154.033c0,5.831-6.49,9.313-11.342,6.099l-9.261-6.14V206.026      c0-6.717-5.45-12.166-12.166-12.166h20.604C470.34,193.859,475.789,199.309,475.789,206.026z M85.278,206.026v154.033c0,5.831-6.48,9.313-11.342,6.099l-9.261-6.14V206.026      c0-6.717-5.45-12.166-12.166-12.166h20.604C79.829,193.859,85.278,199.309,85.278,206.026z`
const SVG_WIDTH = 512
const SVG_HEIGHT = 512

// ── Config ──────────────────────────────────────────────
interface ParticlesConfig {
  gridSize: number
  attractRadius: number
  repelRadius: number
  attractStrength: number
  repelStrength: number
  flickerChance: number
  breatheIntensity: number
  animDuration: number
}

const DEFAULT_CONFIG: ParticlesConfig = {
  "gridSize": 1.5,
  "attractRadius": 106,
  "repelRadius": 100,
  "attractStrength": 0.06,
  "repelStrength": 1.2,
  "flickerChance": 0.11,
  "breatheIntensity": 0.08,
  "animDuration": 3000
}

// ── SVG Utilities ───────────────────────────────────────

// ── Particles Shader ──────────────────────────────────────
interface Particle {
  x: number
  y: number
  vx: number
  vy: number
  targetX: number
  targetY: number
  startX: number
  startY: number
  jitterX: number
  jitterY: number
  delay: number
  alpha: number
  flickerPhase: number
  flickerSpeed: number
  isFlickering: boolean
  flickerStart: number
  density: number
}

function easeOutQuart(t: number): number {
  return 1 - Math.pow(1 - t, 4)
}

function easeInOutCubic(t: number): number {
  return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2
}

interface Props {
  config: ParticlesConfig
  playing?: boolean
  resetKey?: number
  svgScale?: number
  theme?: "light" | "dark"
  svgPath?: string
  svgWidth?: number
  svgHeight?: number
}

export default function ParticlesShader({ config, playing = true, resetKey = 0, svgScale = 1, theme = "dark", svgPath = SVG_PATH, svgWidth = SVG_WIDTH, svgHeight = SVG_HEIGHT }: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const particlesRef = useRef<Particle[]>([])
  const startTimeRef = useRef<number | null>(null)
  const rafRef = useRef<number>(0)
  const mouseRef = useRef<{ x: number; y: number; active: boolean }>({ x: 0, y: 0, active: false })
  const configRef = useRef(config)
  const playingRef = useRef(playing)
  const pausedAtRef = useRef<number | null>(null)
  const pauseOffsetRef = useRef(0)
  const themeRef = useRef(theme)

  configRef.current = config
  playingRef.current = playing
  themeRef.current = theme

  const init = useCallback(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const dpr = window.devicePixelRatio || 1
    const width = window.innerWidth
    const height = window.innerHeight

    canvas.width = width * dpr
    canvas.height = height * dpr
    canvas.style.width = `${width}px`
    canvas.style.height = `${height}px`

    const ctx = canvas.getContext("2d")
    if (!ctx) return
    ctx.scale(dpr, dpr)

    const cfg = configRef.current
    const points = fillSVGPath(svgPath, cfg.gridSize, svgWidth, svgHeight)
    const { scale, offsetX, offsetY } = getLogoTransform(width, height, svgScale, svgWidth, svgHeight)

    const centerX = width / 2
    const centerY = height / 2

    const filteredPoints = points.filter((point) => {
      const edgeProb = point.edgeDist <= 2 ? 1 : 0.6
      const logoCenter = { x: svgWidth / 2, y: svgHeight / 2 }
      const distFromCenter = Math.sqrt(
        Math.pow(point.x - logoCenter.x, 2) + Math.pow(point.y - logoCenter.y, 2)
      )
      const maxDist = Math.sqrt(logoCenter.x * logoCenter.x + logoCenter.y * logoCenter.y)
      const normalizedDist = distFromCenter / maxDist

      // Smooth cosine interpolation avoids a visible circular boundary
      const densityFactor = 0.65 + 0.25 * Math.cos(normalizedDist * Math.PI)

      return Math.random() < edgeProb * densityFactor
    })

    const particles: Particle[] = filteredPoints.map((point) => {
      const targetX = point.x * scale + offsetX
      const targetY = point.y * scale + offsetY

      const jitterAmount = 1.5 + Math.random() * 2
      const jitterX = (Math.random() - 0.5) * jitterAmount
      const jitterY = (Math.random() - 0.5) * jitterAmount

      const angle = Math.random() * Math.PI * 2
      const minRadius = Math.max(width, height) * 0.6
      const maxRadius = Math.max(width, height) * 1.2
      const spawnRadius = minRadius + Math.random() * (maxRadius - minRadius)

      const angleJitter = (Math.random() - 0.5) * 0.5
      const finalAngle = angle + angleJitter

      const startX = centerX + Math.cos(finalAngle) * spawnRadius + (Math.random() - 0.5) * 200
      const startY = centerY + Math.sin(finalAngle) * spawnRadius + (Math.random() - 0.5) * 200

      const distFromCenterVal = Math.sqrt(
        Math.pow(targetX - centerX, 2) + Math.pow(targetY - centerY, 2)
      )
      const maxDistVal = Math.sqrt(
        Math.pow(width / 2, 2) + Math.pow(height / 2, 2)
      )
      const normalizedDist = distFromCenterVal / maxDistVal

      const baseDelay = normalizedDist * 0.6
      const randomDelay = Math.random() * 0.25
      const delay = baseDelay + randomDelay

      const isFlickering = Math.random() < cfg.flickerChance

      return {
        x: startX,
        y: startY,
        vx: 0,
        vy: 0,
        targetX: targetX + jitterX,
        targetY: targetY + jitterY,
        startX,
        startY,
        jitterX,
        jitterY,
        delay,
        alpha: 0,
        flickerPhase: Math.random() * Math.PI * 2,
        flickerSpeed: 0.5 + Math.random() * 2,
        isFlickering,
        flickerStart: 4000 + Math.random() * 2000,
        density: point.edgeDist / 10,
      }
    })

    particlesRef.current = particles
    startTimeRef.current = null
  }, [svgScale, svgPath, svgWidth, svgHeight])

  useEffect(() => {
    init()
    window.addEventListener("resize", init)
    return () => window.removeEventListener("resize", init)
  }, [init])

  useEffect(() => {
    if (resetKey > 0) {
      startTimeRef.current = null
      pauseOffsetRef.current = 0
      pausedAtRef.current = null
      init()
    }
  }, [resetKey, init])

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      mouseRef.current = { x: e.clientX, y: e.clientY, active: true }
    }
    const handleMouseLeave = () => {
      mouseRef.current.active = false
    }
    const handleTouchStart = (e: TouchEvent) => {
      if ((e.target as Element)?.closest?.("[data-controls-panel]")) return
      const touch = e.touches[0]
      if (touch) mouseRef.current = { x: touch.clientX, y: touch.clientY, active: true }
    }
    const handleTouchMove = (e: TouchEvent) => {
      if ((e.target as Element)?.closest?.("[data-controls-panel]")) return
      const touch = e.touches[0]
      if (touch) mouseRef.current = { x: touch.clientX, y: touch.clientY, active: true }
    }
    const handleTouchEnd = () => {
      mouseRef.current.active = false
    }

    window.addEventListener("mousemove", handleMouseMove)
    window.addEventListener("mouseleave", handleMouseLeave)
    window.addEventListener("touchstart", handleTouchStart, { passive: true })
    window.addEventListener("touchmove", handleTouchMove, { passive: true })
    window.addEventListener("touchend", handleTouchEnd)

    return () => {
      window.removeEventListener("mousemove", handleMouseMove)
      window.removeEventListener("mouseleave", handleMouseLeave)
      window.removeEventListener("touchstart", handleTouchStart)
      window.removeEventListener("touchmove", handleTouchMove)
      window.removeEventListener("touchend", handleTouchEnd)
    }
  }, [])

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext("2d")
    if (!ctx) return

    const animate = (timestamp: number) => {
      if (startTimeRef.current === null) {
        startTimeRef.current = timestamp
      }

      if (!playingRef.current) {
        pausedAtRef.current = timestamp
        rafRef.current = requestAnimationFrame(animate)
        return
      }

      if (pausedAtRef.current !== null) {
        pauseOffsetRef.current += timestamp - pausedAtRef.current
        pausedAtRef.current = null
      }

      const cfg = configRef.current
      const elapsed = timestamp - startTimeRef.current - pauseOffsetRef.current
      const duration = cfg.animDuration
      const globalProgress = Math.min(elapsed / duration, 1)

      const dpr = window.devicePixelRatio || 1
      const width = canvas.width / dpr
      const height = canvas.height / dpr

      const isLight = themeRef.current === "light"
      ctx.fillStyle = isLight ? "#f5f5f5" : "#000"
      ctx.fillRect(0, 0, width, height)

      const mouse = mouseRef.current
      const particles = particlesRef.current

      for (let i = 0; i < particles.length; i++) {
        const p = particles[i]

        const particleProgress = Math.max(0, Math.min(1, (globalProgress - p.delay) / (1 - p.delay)))
        const easedProgress = easeOutQuart(particleProgress)

        const baseX = p.startX + (p.targetX - p.startX) * easedProgress
        const baseY = p.startY + (p.targetY - p.startY) * easedProgress

        if (mouse.active && particleProgress > 0.3) {
          const dx = p.x - mouse.x
          const dy = p.y - mouse.y
          const dist = Math.sqrt(dx * dx + dy * dy)

          if (dist < cfg.repelRadius && dist > 0) {
            const force = (1 - dist / cfg.repelRadius) * cfg.repelStrength
            const pushX = (dx / dist) * force * cfg.repelRadius
            const pushY = (dy / dist) * force * cfg.repelRadius
            p.vx += pushX * 0.15
            p.vy += pushY * 0.15
          } else if (dist < cfg.attractRadius && dist > 0) {
            const normalizedDist = (dist - cfg.repelRadius) / (cfg.attractRadius - cfg.repelRadius)
            const force = (1 - normalizedDist) * cfg.attractStrength
            const pullX = -(dx / dist) * force * (cfg.attractRadius - cfg.repelRadius)
            const pullY = -(dy / dist) * force * (cfg.attractRadius - cfg.repelRadius)
            p.vx += pullX * 0.08
            p.vy += pullY * 0.08
          }
        }

        const distToTarget = Math.sqrt(Math.pow(baseX - p.x, 2) + Math.pow(baseY - p.y, 2))
        const maxReturnDist = 300
        const normalizedDist = Math.min(distToTarget / maxReturnDist, 1)
        const easeInFactor = normalizedDist * normalizedDist * normalizedDist
        const returnStrength = 0.008 + easeInFactor * 0.12

        p.vx += (baseX - p.x) * returnStrength
        p.vy += (baseY - p.y) * returnStrength

        const dampingFactor = 0.92 - easeInFactor * 0.08
        p.vx *= dampingFactor
        p.vy *= dampingFactor

        p.x += p.vx
        p.y += p.vy

        let alpha = Math.min(1, particleProgress * 2)

        if (p.isFlickering && elapsed > p.flickerStart && particleProgress >= 1) {
          const flickerTime = elapsed - p.flickerStart
          const flickerCycle = Math.sin(flickerTime * 0.003 * p.flickerSpeed + p.flickerPhase)

          if (flickerCycle < -0.7) {
            const fadeProgress = (flickerCycle + 1) / 0.3
            alpha = easeInOutCubic(fadeProgress) * 0.3
          } else if (flickerCycle < -0.4) {
            alpha = 0.3 + (flickerCycle + 0.7) / 0.3 * 0.7
          }
        }

        if (particleProgress >= 1) {
          const breathe = Math.sin(elapsed * 0.001 + p.flickerPhase) * cfg.breatheIntensity
          alpha = Math.max(0.2, Math.min(1, alpha + breathe))
        }

        p.alpha = alpha

        if (isLight) {
          const boosted = Math.min(1, p.alpha * 1.4 + 0.1)
          ctx.fillStyle = `rgba(0, 0, 0, ${boosted})`
          const px = Math.round(p.x)
          const py = Math.round(p.y)
          ctx.fillRect(px, py, 2, 2)
        } else {
          ctx.fillStyle = `rgba(255, 255, 255, ${p.alpha})`
          ctx.fillRect(Math.round(p.x), Math.round(p.y), 1, 1)
        }
      }

      rafRef.current = requestAnimationFrame(animate)
    }

    rafRef.current = requestAnimationFrame(animate)

    return () => {
      if (rafRef.current) {
        cancelAnimationFrame(rafRef.current)
      }
    }
  }, [])

  return (
    <canvas
      ref={canvasRef}
      className="fixed inset-0 w-full h-full"
      style={{ background: theme === "light" ? "#f5f5f5" : "#000", touchAction: "none" }}
    />
  )
}
