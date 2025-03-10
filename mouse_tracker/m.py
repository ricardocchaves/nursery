import tkinter as tk
from tkinter import ttk
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
import numpy as np
import time
import sys
import subprocess
from collections import deque

class MouseTracker:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Mouse Position Tracker")
        
        # Make window open maximized
        screen_width = self.root.winfo_screenwidth()
        screen_height = self.root.winfo_screenheight()
        self.root.geometry(f"{screen_width}x{screen_height}")
        
        # Get screen refresh rate (Linux-specific)
        self.refresh_rate = self.get_linux_refresh_rate()
        self.update_interval = int(1000 / self.refresh_rate)  # Convert to milliseconds

        # Initialize data storage
        self.max_history = 1000
        self.x_coords = deque(maxlen=self.max_history)
        self.y_coords = deque(maxlen=self.max_history)
        self.timestamps = deque(maxlen=self.max_history)
        self.trail_x = deque(maxlen=100)
        self.trail_y = deque(maxlen=100)
        self.start_time = time.time()
        
        # Auto-scroll flag
        self.auto_scroll = True
        
        # Current view indices
        self.view_start = 0
        self.view_end = 0
        
        # Create main container
        self.container = ttk.Frame(self.root)
        self.container.pack(fill=tk.BOTH, expand=True)
        
        # Create figures
        self.setup_plots()
        
        # Add controls
        self.setup_controls()
        
        # Bind window close event
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
        
        # Start the update loop
        self.update_all()
        
    def get_linux_refresh_rate(self):
        try:
            # Try to get refresh rate using xrandr
            output = subprocess.check_output(["xrandr", "--current"], universal_newlines=True)
            
            # Parse the output to find the current refresh rate
            for line in output.splitlines():
                if "*+" not in line:
                    continue

                parts = line.split()
                for part in parts:
                    if "*+" not in part:
                        continue

                    rate = float(part[:-2])
                    return int(np.ceil(rate))
        except Exception as e:
            print(f"Error getting refresh rate: {e}")
        
        return 60
        
    def setup_plots(self):
        # Position plot
        self.fig1 = plt.Figure(figsize=(6, 4), dpi=100)
        self.ax1 = self.fig1.add_subplot(111)
        self.line1, = self.ax1.plot([], [], 'r-', alpha=0.7)  # Trail line
        self.scatter1 = self.ax1.scatter([], [], s=10, c=[], cmap='viridis', alpha=0.6)  # Data points
        self.point1, = self.ax1.plot([], [], 'bo', markersize=8)  # Current position
        
        # Set axis limits with Y-axis inverted
        self.ax1.set_xlim(0, self.root.winfo_screenwidth())
        self.ax1.set_ylim(self.root.winfo_screenheight(), 0)  # Inverted Y-axis
        self.ax1.set_title('Current Mouse Position (Y-axis inverted)')
        self.ax1.set_xlabel('X Coordinate')
        self.ax1.set_ylabel('Y Coordinate (0 at top)')
        
        self.canvas1 = FigureCanvasTkAgg(self.fig1, master=self.container)
        self.canvas1.get_tk_widget().pack(fill=tk.BOTH, expand=True)
        
        # History plots
        self.fig2 = plt.Figure(figsize=(6, 4), dpi=100)
        self.ax2 = self.fig2.add_subplot(211)
        self.ax3 = self.fig2.add_subplot(212)
        
        self.line2, = self.ax2.plot([], [], 'b-')
        self.line3, = self.ax3.plot([], [], 'g-')
        
        self.ax2.set_title('X Coordinate History')
        self.ax2.set_ylabel('X Position')
        self.ax2.set_xlabel('Time (seconds)')
        self.ax2.grid(True)
        
        self.ax3.set_title('Y Coordinate History')
        self.ax3.set_ylabel('Y Position')
        self.ax3.set_xlabel('Time (seconds)')
        self.ax3.grid(True)
        
        self.canvas2 = FigureCanvasTkAgg(self.fig2, master=self.container)
        self.canvas2.get_tk_widget().pack(fill=tk.BOTH, expand=True)
        
        # Initial draw to set up the canvas
        self.fig1.tight_layout()
        self.fig2.tight_layout()
        self.canvas1.draw()
        self.canvas2.draw()
    
    def setup_controls(self):
        # Control frame
        control_frame = ttk.Frame(self.container)
        control_frame.pack(fill=tk.X, padx=5, pady=5)
        
        # Auto-scroll checkbox
        self.auto_scroll_var = tk.BooleanVar(value=True)
        auto_scroll_check = ttk.Checkbutton(
            control_frame, 
            text="Auto-scroll", 
            variable=self.auto_scroll_var,
            command=self.toggle_auto_scroll
        )
        auto_scroll_check.pack(side=tk.LEFT, padx=5)
        
        # Scrollbar
        self.scrollbar = ttk.Scale(
            control_frame,
            from_=0,
            to=100,
            orient=tk.HORIZONTAL,
            command=self.manual_scroll
        )
        self.scrollbar.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=5)
        
        # Status label
        self.status_label = ttk.Label(control_frame, text="Points: 0")
        self.status_label.pack(side=tk.RIGHT, padx=5)
        
        # Refresh rate label
        refresh_label = ttk.Label(control_frame, text=f"Refresh: {self.refresh_rate}Hz")
        refresh_label.pack(side=tk.RIGHT, padx=5)
        
        # Exit button
        exit_button = ttk.Button(control_frame, text="Exit", command=self.on_closing)
        exit_button.pack(side=tk.RIGHT, padx=5)
    
    def toggle_auto_scroll(self):
        self.auto_scroll = self.auto_scroll_var.get()
    
    def manual_scroll(self, value):
        if self.auto_scroll_var.get():
            self.auto_scroll_var.set(False)
            self.auto_scroll = False
        
        if len(self.timestamps) < 2:
            return
            
        # Calculate view window
        window_size = max(int(len(self.timestamps) * 0.2), 100)
        max_start = max(0, len(self.timestamps) - window_size)
        start_idx = min(int(float(value) / 100 * max_start), max_start)
        end_idx = min(start_idx + window_size, len(self.timestamps))
        
        self.view_start = start_idx
        self.view_end = end_idx
    
    def calculate_view_window(self):
        if len(self.timestamps) < 2:
            return 0, 0

        window_size = max(int(len(self.timestamps) * 0.2), 100)
        
        if self.auto_scroll:
            self.scrollbar.set(100)

        start_idx = max(0, len(self.timestamps) - window_size)
        end_idx = len(self.timestamps)

        return start_idx, end_idx
    
    def update_all(self):
        try:
            # Get current mouse position
            x, y = self.root.winfo_pointerxy()
            current_time = time.time() - self.start_time
            
            # Update data
            self.x_coords.append(x)
            self.y_coords.append(y)
            self.timestamps.append(current_time)
            
            # Update trail
            self.trail_x.append(x)
            self.trail_y.append(y)
            
            # Update position plot
            self.line1.set_data(list(self.trail_x), list(self.trail_y))
            self.point1.set_data([x], [y])
            
            # Update scatter plot with the latest 100 data points
            x_list = list(self.x_coords)[-100:]
            y_list = list(self.y_coords)[-100:]
            
            # Create color array based on time (newer points are brighter)
            colors = np.linspace(0, 1, len(x_list))
            
            # Update scatter plot
            self.scatter1.set_offsets(np.column_stack([x_list, y_list]))
            self.scatter1.set_array(colors)
            
            self.canvas1.draw_idle()
            
            # Update history plots
            if len(self.timestamps) >= 10:
                start_idx, end_idx = self.calculate_view_window()
                if start_idx < end_idx:
                    self.update_history_plots(start_idx, end_idx)
            
            # Update status
            self.status_label.config(text=f"Points: {len(self.x_coords)} | Current: ({x}, {y})")
            
            # Schedule next update at screen refresh rate
            self.root.after(self.update_interval, self.update_all)
            
        except Exception as e:
            print(f"Error in update: {e}")
            # Try to continue anyway
            self.root.after(self.update_interval, self.update_all)
    
    def update_history_plots(self, start_idx, end_idx):
        try:
            if start_idx >= end_idx or start_idx < 0 or end_idx > len(self.timestamps):
                return
            
            # Convert deques to lists for slicing
            timestamps = list(self.timestamps)
            x_coords = list(self.x_coords)
            y_coords = list(self.y_coords)
            
            # Update data for the lines
            self.line2.set_data(timestamps[start_idx:end_idx], x_coords[start_idx:end_idx])
            self.line3.set_data(timestamps[start_idx:end_idx], y_coords[start_idx:end_idx])
            
            # Calculate axis limits
            time_min = timestamps[start_idx]
            time_max = timestamps[end_idx-1]
            time_padding = max((time_max - time_min) * 0.05, 0.1)
            
            y_min_x = min(x_coords[start_idx:end_idx])
            y_max_x = max(x_coords[start_idx:end_idx])
            y_padding_x = max((y_max_x - y_min_x) * 0.1, 10)
            
            y_min_y = min(y_coords[start_idx:end_idx])
            y_max_y = max(y_coords[start_idx:end_idx])
            y_padding_y = max((y_max_y - y_min_y) * 0.1, 10)
            
            # Set axis limits
            self.ax2.set_xlim(time_min - time_padding, time_max + time_padding)
            self.ax3.set_xlim(time_min - time_padding, time_max + time_padding)
            self.ax2.set_ylim(y_min_x - y_padding_x, y_max_x + y_padding_x)
            self.ax3.set_ylim(y_min_y - y_padding_y, y_max_y + y_padding_y)
            
            # Draw the updated plots
            self.canvas2.draw_idle()
                
        except Exception as e:
            print(f"Error updating history plots: {e}")
    
    def on_closing(self):
        print("Cleaning up and exiting...")
        try:
            # Cancel the update loops
            self.root.after_cancel(self.update_all)
        except:
            pass
            
        # Close all figures
        plt.close('all')
        
        # Destroy the window
        self.root.destroy()
        print("Exited cleanly.")
    
    def run(self):
        try:
            self.root.mainloop()
        except KeyboardInterrupt:
            self.on_closing()

if __name__ == "__main__":
    tracker = MouseTracker()
    try:
        tracker.run()
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)