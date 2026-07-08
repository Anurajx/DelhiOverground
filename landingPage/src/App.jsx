import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { ArrowRight, ArrowUpRight, Download } from "lucide-react";
import "./App.css";

function AnimatedText({ text }) {
  return (
    <span
      className="font-light text-center text-6xl leading-[0.75] tracking-tighter font-serif text-white mix-blend-difference lg:text-9xl"
      style={{ display: "inline-block" }}
    >
      {text}
    </span>
  );
}

function HeroSection() {
  const [loaded, setLoaded] = useState(false);
  const [scrollProgress, setScrollProgress] = useState(0);

  useEffect(() => {
    const timer = setTimeout(() => {
      setLoaded(true);
    }, 100);
    return () => clearTimeout(timer);
  }, []);

  useEffect(() => {
    let frameId;
    let currentScroll = 0;

    const handleScroll = () => {
      const targetScroll = Math.min(window.scrollY / 400, 1);
      const update = () => {
        currentScroll += (targetScroll - currentScroll) * 0.1;
        if (Math.abs(targetScroll - currentScroll) > 0.001) {
          setScrollProgress(currentScroll);
          frameId = requestAnimationFrame(update);
        } else {
          setScrollProgress(targetScroll);
        }
      };
      cancelAnimationFrame(frameId);
      update();
    };

    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => {
      window.removeEventListener("scroll", handleScroll);
      cancelAnimationFrame(frameId);
    };
  }, []);

  const borderRadius = 48 * (1 - Math.pow(1 - scrollProgress, 3));
  const scale = 1 - scrollProgress * (2 - scrollProgress) * 0.15;
  const height = 100 - scrollProgress * (2 - scrollProgress) * 37.5;
  const translateY = 150 * scrollProgress;
  const opacity = 1 - 0.8 * scrollProgress;

  return (
    <section className="pt-32 pb-12 px-6 min-h-screen flex items-center relative overflow-hidden">
      {/* Background Image Container */}
      <div className="absolute inset-0 top-0">
        <div
          className="w-full will-change-transform overflow-hidden"
          style={{
            transform: `scale(${scale})`,
            borderRadius: `${borderRadius}px`,
            height: `${height}vh`,
          }}
        >
          <img
            src="/images/ravi-sharma-final.webp"
            alt="Scenic view of Delhi landscape"
            className="w-full h-full object-cover"
          />
        </div>
      </div>

      {/* Main Content */}
      <div className="max-w-7xl mx-auto w-full relative">
        <div className="text-center mb-12">
          <div>
            <h1 className="font-serif text-[3.5rem] sm:text-[4.5rem] md:text-[5.5rem] lg:text-[6.5rem] xl:text-[7.5rem] 2xl:text-[8.5rem] font-normal leading-tight mb-6 w-full px-4 max-w-6xl mx-auto text-balance">
              <AnimatedText text="Find your way through Delhi NCR" />
            </h1>
            <p className="text-white mix-blend-difference text-lg sm:text-xl lg:text-2xl max-w-xl lg:max-w-2xl mx-auto font-sans mt-4 mb-2 text-balance opacity-80">
              Accessibility to public transit.
            </p>
          </div>
        </div>
        <div className="flex flex-col items-center justify-center gap-8">
          <div className="relative">
            <div
              className={`relative w-[234px] md:w-[281px] lg:w-[351px] mockup-aspect will-change-transform mockup-transition delay-500 ${
                loaded ? "mockup-loaded" : "mockup-initial"
              }`}
            >
              <img
                src="/images/delhi-overground-mockup.png"
                alt="Delhi Overground journey planner app"
                className="w-full h-full object-contain relative z-10"
              />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function App() {
  const [toast, setToast] = useState({ show: false, message: "" });
  const [showHeart, setShowHeart] = useState(false);

  const triggerToast = (message) => {
    setToast({ show: true, message });
  };

  useEffect(() => {
    if (toast.show) {
      const timer = setTimeout(() => {
        setToast((prev) => ({ ...prev, show: false }));
      }, 8000);
      return () => clearTimeout(timer);
    }
  }, [toast.show, toast.message]);

  const handleDownload = (e, url, message) => {
    e.preventDefault();
    triggerToast(message);
    setShowHeart(true);

    // Create an invisible iframe to trigger the background file download
    const iframe = document.createElement("iframe");
    iframe.style.display = "none";
    iframe.src = url;
    document.body.appendChild(iframe);

    // Clean up the iframe after 2 seconds
    setTimeout(() => {
      document.body.removeChild(iframe);
    }, 2000);
  };

  return (
    <main className="min-h-screen bg-background">
      <HeroSection />

      <section className="py-32 px-6 relative overflow-hidden">
        <div className="max-w-7xl mx-auto relative z-10">
          <div className="text-center mb-16">
            <h2 className="text-4xl md:text-5xl font-normal leading-tight max-w-4xl mx-auto mb-6 font-serif">
              Ready to go your way around?
            </h2>
            <p className="text-muted-foreground max-w-2xl mx-auto mb-10">
              Download app below, let google do its thing and install. Simple as
              that
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <a
                href="https://github.com/Anurajx/DelhiOverground/releases/download/v1.0.0/DelhiOverground.apk"
                onClick={(e) => handleDownload(e, "https://github.com/Anurajx/DelhiOverground/releases/download/v1.0.0/DelhiOverground.apk", "Downloading DTC App")}
                className="no-underline relative flex items-center justify-center gap-0 bg-foreground text-background rounded-full pl-6 pr-1.5 py-1.5 transition-all duration-300 group overflow-hidden"
              >
                <span className="text-sm pr-4">DelhiOverground (DTC)</span>
                <span className="w-10 h-10 bg-background rounded-full flex items-center justify-center">
                  <ArrowUpRight className="w-4 h-4 text-foreground" />
                </span>
              </a>
              <a
                href="https://github.com/Anurajx/DelhiUnderground/releases/download/v1.0.0/app-release.apk"
                onClick={(e) => handleDownload(e, "https://github.com/Anurajx/DelhiUnderground/releases/download/v1.0.0/app-release.apk", "Downloading Metro App")}
                className="no-underline relative flex items-center justify-center gap-0 border border-border rounded-full pl-6 pr-1.5 py-1.5 transition-all duration-300 group overflow-hidden"
              >
                <span className="absolute inset-0 bg-foreground rounded-full scale-x-0 origin-right group-hover:scale-x-100 transition-transform duration-300"></span>
                <span className="text-sm text-foreground group-hover:text-background pr-4 relative z-10 transition-colors duration-300">
                  DelhiUnderground (Metro *Outdated)
                </span>
                <span className="w-10 h-10 rounded-full flex items-center justify-center relative z-10">
                  <ArrowRight className="w-4 h-4 text-foreground group-hover:opacity-0 absolute transition-opacity duration-300" />
                  <ArrowUpRight className="w-4 h-4 text-foreground group-hover:text-background opacity-0 group-hover:opacity-100 transition-all duration-300" />
                </span>
              </a>
            </div>

            {showHeart && (
              <div className="flex justify-center heart-container">
                <img
                  src="/images/pixel-heart-2779422_1280.png"
                  alt="Pixel Heart"
                  className="w-4 h-4 object-contain heart-spawn"
                />
              </div>
            )}
          </div>
        </div>
      </section>

      {/* Toast Notification */}
      <div className={`toast-container ${toast.show ? "show" : ""}`}>
        <div className="toast-icon">
          <Download className="w-4 h-4" />
        </div>
        <span className="toast-text">{toast.message}</span>
      </div>
    </main>
  );
}

export default App;

