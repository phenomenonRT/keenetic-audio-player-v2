package main

import (
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

type PlaylistItem struct {
	ID       string `json:"id"`
	Number   int    `json:"number"`
	Name     string `json:"name"`
	Filename string `json:"filename"`
	Path     string `json:"path"`
	Added    int64  `json:"added"`
	Duration int    `json:"duration"`
}

type Playlist struct {
	Items []PlaylistItem `json:"items"`
}

type AppState struct {
	mu           sync.Mutex
	currentTrack *PlaylistItem
	isPlaying    bool
	process      *exec.Cmd
	playlist     Playlist
	mediaDir     string
	installDir   string
	nextNumber   int
}

var appState = &AppState{
	playlist: Playlist{
		Items: make([]PlaylistItem, 0),
	},
}

const (
	RELATIVE_MEDIA_DIR = "media"
	PORT               = ":8080"
	VOICE_MAX_SIZE     = 50 << 20 // 50 МБ для голосовых сообщений
)

func init() {
	ex, err := os.Executable()
	if err != nil {
		panic(err)
	}
	appState.installDir = filepath.Dir(ex)
	appState.mediaDir = filepath.Join(appState.installDir, RELATIVE_MEDIA_DIR)

	os.MkdirAll(appState.mediaDir, 0755)
	scanMediaFolder()
}

func scanMediaFolder() {
	appState.mu.Lock()
	defer appState.mu.Unlock()

	appState.playlist.Items = make([]PlaylistItem, 0)
	appState.nextNumber = 1

	files, err := ioutil.ReadDir(appState.mediaDir)
	if err != nil {
		fmt.Printf("Error scanning media directory: %v\n", err)
		return
	}

	validExts := map[string]bool{
		".mp3":  true,
		".wav":  true,
		".flac": true,
		".m4a":  true,
	}

	for _, file := range files {
		if file.IsDir() {
			continue
		}

		ext := strings.ToLower(filepath.Ext(file.Name()))
		if !validExts[ext] {
			continue
		}

		filePath := filepath.Join(appState.mediaDir, file.Name())
		trackName := strings.TrimSuffix(file.Name(), ext)

		item := PlaylistItem{
			ID:       fmt.Sprintf("track_%d", time.Now().UnixNano()),
			Number:   appState.nextNumber,
			Name:     trackName,
			Filename: file.Name(),
			Path:     filePath,
			Added:    time.Now().Unix(),
		}

		appState.playlist.Items = append(appState.playlist.Items, item)
		appState.nextNumber++
	}

	sort.Slice(appState.playlist.Items, func(i, j int) bool {
		return appState.playlist.Items[i].Number < appState.playlist.Items[j].Number
	})

	fmt.Printf("Loaded %d media files\n", len(appState.playlist.Items))
}

func handleGetPlaylist(w http.ResponseWriter, r *http.Request) {
	appState.mu.Lock()
	playlist := appState.playlist
	currentTrack := appState.currentTrack
	isPlaying := appState.isPlaying

	for i := range playlist.Items {
		playlist.Items[i].Duration = 0
		if currentTrack != nil && playlist.Items[i].ID == currentTrack.ID && isPlaying {
			playlist.Items[i].Duration = 1
		}
	}
	appState.mu.Unlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(playlist)
}

func handleAddTrack(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	r.ParseMultipartForm(100 << 20)

	file, handler, err := r.FormFile("audio")
	if err != nil {
		http.Error(w, "Error getting file", http.StatusBadRequest)
		return
	}
	defer file.Close()

	ext := strings.ToLower(filepath.Ext(handler.Filename))
	validExts := map[string]bool{
		".mp3":  true,
		".wav":  true,
		".flac": true,
		".m4a":  true,
	}

	if !validExts[ext] {
		http.Error(w, "Unsupported format", http.StatusBadRequest)
		return
	}

	filename := handler.Filename
	filePath := filepath.Join(appState.mediaDir, filename)

	dst, err := os.Create(filePath)
	if err != nil {
		http.Error(w, "Error saving file", http.StatusInternalServerError)
		return
	}
	defer dst.Close()

	if _, err := io.Copy(dst, file); err != nil {
		os.Remove(filePath)
		http.Error(w, "Error writing file", http.StatusInternalServerError)
		return
	}

	appState.mu.Lock()

	trackName := r.FormValue("name")
	if trackName == "" {
		trackName = strings.TrimSuffix(handler.Filename, ext)
	}

	item := PlaylistItem{
		ID:       fmt.Sprintf("track_%d", time.Now().UnixNano()),
		Number:   appState.nextNumber,
		Name:     trackName,
		Filename: filename,
		Path:     filePath,
		Added:    time.Now().Unix(),
	}

	appState.playlist.Items = append(appState.playlist.Items, item)
	appState.nextNumber++

	appState.mu.Unlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status": "success",
		"id":     item.ID,
		"number": item.Number,
		"name":   item.Name,
	})
}

func handleRemoveTrack(w http.ResponseWriter, r *http.Request) {
	trackID := r.URL.Query().Get("id")
	if trackID == "" {
		http.Error(w, "ID not specified", http.StatusBadRequest)
		return
	}

	appState.mu.Lock()
	defer appState.mu.Unlock()

	if appState.currentTrack != nil && appState.currentTrack.ID == trackID {
		if appState.process != nil && appState.process.ProcessState == nil {
			appState.process.Process.Kill()
		}
		appState.isPlaying = false
		appState.currentTrack = nil
	}

	for i, item := range appState.playlist.Items {
		if item.ID == trackID {
			os.Remove(item.Path)
			appState.playlist.Items = append(appState.playlist.Items[:i], appState.playlist.Items[i+1:]...)
			break
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "deleted"})
}

func handleRemoveMultiple(w http.ResponseWriter, r *http.Request) {
	ids := r.URL.Query()["ids"]
	if len(ids) == 0 {
		http.Error(w, "No IDs specified", http.StatusBadRequest)
		return
	}

	appState.mu.Lock()
	defer appState.mu.Unlock()

	for _, trackID := range ids {
		if appState.currentTrack != nil && appState.currentTrack.ID == trackID {
			if appState.process != nil && appState.process.ProcessState == nil {
				appState.process.Process.Kill()
			}
			appState.isPlaying = false
			appState.currentTrack = nil
		}

		for i, item := range appState.playlist.Items {
			if item.ID == trackID {
				os.Remove(item.Path)
				appState.playlist.Items = append(appState.playlist.Items[:i], appState.playlist.Items[i+1:]...)
				break
			}
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "deleted"})
}

func handlePlay(w http.ResponseWriter, r *http.Request) {
	trackID := r.URL.Query().Get("id")
	if trackID == "" {
		http.Error(w, "ID not specified", http.StatusBadRequest)
		return
	}

	appState.mu.Lock()
	defer appState.mu.Unlock()

	if appState.process != nil && appState.process.ProcessState == nil {
		appState.process.Process.Kill()
	}

	var selectedTrack *PlaylistItem
	for i := range appState.playlist.Items {
		if appState.playlist.Items[i].ID == trackID {
			selectedTrack = &appState.playlist.Items[i]
			break
		}
	}

	if selectedTrack == nil {
		http.Error(w, "Track not found", http.StatusNotFound)
		return
	}

	if _, err := os.Stat(selectedTrack.Path); err != nil {
		http.Error(w, "File not found", http.StatusNotFound)
		return
	}

	audioDevice := r.URL.Query().Get("device")
	if audioDevice == "" {
		audioDevice = "hw:0,0"
	}

	var cmd *exec.Cmd

	if _, err := exec.LookPath("mpg123"); err == nil {
		cmd = exec.Command("mpg123", "-a", audioDevice, selectedTrack.Path)
	} else if _, err := exec.LookPath("ffplay"); err == nil {
		cmd = exec.Command("ffplay", "-nodisp", "-autoexit", selectedTrack.Path)
	} else if _, err := exec.LookPath("aplay"); err == nil {
		cmd = exec.Command("aplay", "-D", audioDevice, selectedTrack.Path)
	} else {
		http.Error(w, "Player not found", http.StatusInternalServerError)
		return
	}

	if err := cmd.Start(); err != nil {
		http.Error(w, fmt.Sprintf("Error starting player: %v", err), http.StatusInternalServerError)
		return
	}

	appState.currentTrack = selectedTrack
	appState.isPlaying = true
	appState.process = cmd

	go func() {
		cmd.Wait()
		appState.mu.Lock()
		appState.isPlaying = false
		appState.mu.Unlock()
	}()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "playing",
		"track":  trackID,
	})
}

func handleStop(w http.ResponseWriter, r *http.Request) {
	appState.mu.Lock()
	defer appState.mu.Unlock()

	if appState.process != nil && appState.process.ProcessState == nil {
		appState.process.Process.Kill()
		appState.isPlaying = false
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "stopped"})
}

// ==================== PTT (Press to Talk) Функции ====================

func handleVoiceData(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	routerIP := r.URL.Query().Get("router")
	audioDevice := r.URL.Query().Get("device")

	if audioDevice == "" {
		audioDevice = "hw:0,0"
	}

	defer r.Body.Close()

	data, err := ioutil.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading data", http.StatusBadRequest)
		return
	}

	tempFile := filepath.Join(appState.mediaDir, fmt.Sprintf("voice_%d.webm", time.Now().UnixNano()))

	err = ioutil.WriteFile(tempFile, data, 0644)
	if err != nil {
		http.Error(w, "Error saving file", http.StatusInternalServerError)
		return
	}

	// Отправить на другой роутер если указан IP
	if routerIP != "" {
		go sendToRouter(tempFile, routerIP, audioDevice)
	} else {
		// Воспроизвести локально
		go playLocalVoice(tempFile, audioDevice)
	}

	// Удалить временный файл через несколько секунд
	go func() {
		time.Sleep(10 * time.Second)
		os.Remove(tempFile)
	}()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "received",
	})
}

func handlePlayVoice(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	audioDevice := r.URL.Query().Get("device")
	if audioDevice == "" {
		audioDevice = "hw:0,0"
	}

	defer r.Body.Close()

	data, err := ioutil.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading data", http.StatusBadRequest)
		return
	}

	tempFile := filepath.Join(appState.mediaDir, fmt.Sprintf("voice_%d.webm", time.Now().UnixNano()))

	err = ioutil.WriteFile(tempFile, data, 0644)
	if err != nil {
		http.Error(w, "Error saving file", http.StatusInternalServerError)
		return
	}

	go playLocalVoice(tempFile, audioDevice)

	// Удалить временный файл
	go func() {
		time.Sleep(10 * time.Second)
		os.Remove(tempFile)
	}()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "playing",
	})
}

func playLocalVoice(filePath string, audioDevice string) {
	appState.mu.Lock()
	if appState.process != nil && appState.process.ProcessState == nil {
		appState.process.Process.Kill()
	}
	appState.mu.Unlock()

	// Попробуем разные плееры
	var cmd *exec.Cmd

	// Сначала ffplay (лучше всего работает с webm)
	if _, err := exec.LookPath("ffplay"); err == nil {
		cmd = exec.Command("ffplay", "-nodisp", "-autoexit", filePath)
	} else if _, err := exec.LookPath("mpg123"); err == nil {
		cmd = exec.Command("mpg123", "-a", audioDevice, filePath)
	} else if _, err := exec.LookPath("aplay"); err == nil {
		cmd = exec.Command("aplay", "-D", audioDevice, filePath)
	}

	if cmd != nil {
		cmd.Start()
		appState.process = cmd

		go func() {
			cmd.Wait()
			appState.mu.Lock()
			appState.isPlaying = false
			appState.mu.Unlock()
		}()
	}
}

func sendToRouter(filePath string, routerIP string, audioDevice string) {
	file, err := os.Open(filePath)
	if err != nil {
		fmt.Printf("Error opening file: %v\n", err)
		return
	}
	defer file.Close()

	resp, err := http.Post(
		fmt.Sprintf("http://%s:8080/api/play-voice?device=%s", routerIP, audioDevice),
		"audio/webm",
		file,
	)

	if err != nil {
		fmt.Printf("Error sending to router: %v\n", err)
		return
	}
	defer resp.Body.Close()
}

func handleIndex(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	fmt.Fprint(w, getHTMLContent())
}

func getHTMLContent() string {
	return `<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<title>Audio Player v2.0+ with PTT</title>
	<style>
		* {
			margin: 0;
			padding: 0;
			box-sizing: border-box;
		}

		:root {
			--primary: #667eea;
			--secondary: #764ba2;
			--danger: #ff6b6b;
			--dark: #2d3436;
			--light: #f5f7fa;
		}

		body {
			font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
			background: linear-gradient(135deg, var(--primary) 0%, var(--secondary) 100%);
			min-height: 100vh;
			color: var(--dark);
			margin: 0;
		}

		header {
			background: white;
			padding: 12px 20px;
			display: flex;
			justify-content: space-between;
			align-items: center;
			box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
			position: sticky;
			top: 0;
			z-index: 100;
			flex-wrap: wrap;
			gap: 10px;
		}

		header h1 {
			font-size: 1.3em;
			margin: 0;
			color: var(--primary);
			font-weight: 700;
			flex: 1;
		}

		.header-buttons {
			display: flex;
			gap: 10px;
			flex-wrap: wrap;
		}

		.btn-header {
			padding: 8px 16px;
			border: none;
			border-radius: 6px;
			cursor: pointer;
			font-weight: 600;
			font-size: 0.9em;
			transition: all 0.2s ease;
			white-space: nowrap;
		}

		.btn-upload {
			background: var(--primary);
			color: white;
		}

		.btn-upload:hover {
			background: #5568d3;
			transform: translateY(-2px);
		}

		.btn-stop {
			background: var(--danger);
			color: white;
		}

		.btn-stop:hover {
			background: #ff5252;
			transform: translateY(-2px);
		}

		.btn-ptt {
			background: #4ecdc4;
			color: white;
		}

		.btn-ptt:hover {
			background: #45b8aa;
			transform: translateY(-2px);
		}

		.btn-delete-header {
			background: #ffa502;
			color: white;
		}

		.btn-delete-header:hover {
			background: #ff9500;
			transform: translateY(-2px);
		}

		.btn-delete-header.active {
			background: #ff7c00;
		}

		.container {
			padding: 0;
			height: calc(100vh - 60px);
			display: flex;
			flex-direction: column;
		}

		.tabs {
			display: flex;
			background: white;
			border-bottom: 1px solid #e0e0e0;
			padding: 0 20px;
			gap: 0;
		}

		.tab-btn {
			padding: 12px 20px;
			border: none;
			background: transparent;
			cursor: pointer;
			font-weight: 600;
			color: #999;
			border-bottom: 3px solid transparent;
			transition: all 0.2s ease;
		}

		.tab-btn.active {
			color: var(--primary);
			border-bottom-color: var(--primary);
		}

		.tab-btn:hover {
			color: var(--primary);
		}

		.tab-content {
			display: none;
			flex: 1;
			overflow-y: auto;
		}

		.tab-content.active {
			display: flex;
			flex-direction: column;
		}

		.track-list {
			flex: 1;
			overflow-y: auto;
			padding: 10px;
			display: flex;
			flex-direction: column;
			gap: 8px;
		}

		.track-item {
			display: flex;
			align-items: center;
			justify-content: space-between;
			padding: 12px 16px;
			background: white;
			border-radius: 8px;
			cursor: pointer;
			border-left: 4px solid transparent;
			transition: all 0.2s ease;
			box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
		}

		.track-item:hover {
			transform: translateX(4px);
			box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
			border-left-color: var(--primary);
		}

		.track-item.playing {
			background: linear-gradient(135deg, rgba(102, 126, 234, 0.15) 0%, rgba(118, 75, 162, 0.08) 100%);
			border-left-color: var(--primary);
		}

		.track-item.selected {
			background: linear-gradient(135deg, rgba(255, 165, 2, 0.15) 0%, rgba(255, 165, 2, 0.08) 100%);
			border-left-color: #ffa502;
		}

		.track-checkbox {
			display: none;
			margin-right: 10px;
			width: 18px;
			height: 18px;
			cursor: pointer;
		}

		.track-checkbox.visible {
			display: block;
		}

		.track-number {
			font-weight: 700;
			color: var(--primary);
			min-width: 30px;
			text-align: center;
			margin-right: 10px;
			font-size: 1.1em;
		}

		.track-info {
			flex: 1;
			min-width: 0;
		}

		.track-name {
			font-weight: 600;
			color: var(--dark);
			font-size: 1em;
			margin-bottom: 3px;
			word-break: break-word;
		}

		.track-item.playing .track-name {
			color: var(--primary);
		}

		.track-meta {
			font-size: 0.75em;
			color: #999;
		}

		/* PTT Стили */
		.ptt-section {
			padding: 20px;
			display: flex;
			flex-direction: column;
			align-items: center;
			justify-content: center;
			gap: 20px;
		}

		.ptt-button {
			width: 120px;
			height: 120px;
			border-radius: 60px;
			border: none;
			background: linear-gradient(135deg, #4ecdc4 0%, #45b8aa 100%);
			color: white;
			font-size: 2.5em;
			cursor: pointer;
			transition: all 0.2s ease;
			box-shadow: 0 10px 30px rgba(78, 205, 196, 0.3);
			user-select: none;
			touch-action: manipulation;
			display: flex;
			align-items: center;
			justify-content: center;
		}

		.ptt-button:active {
			transform: scale(0.95);
			box-shadow: 0 5px 15px rgba(78, 205, 196, 0.3);
		}

		.ptt-button.recording {
			background: linear-gradient(135deg, var(--danger) 0%, #ff5252 100%);
			box-shadow: 0 10px 30px rgba(255, 107, 107, 0.3);
			animation: pulse 1s infinite;
		}

		@keyframes pulse {
			0%, 100% { opacity: 1; }
			50% { opacity: 0.8; }
		}

		.ptt-info {
			text-align: center;
			color: white;
			font-size: 0.9em;
		}

		.ptt-status {
			text-align: center;
			padding: 10px 20px;
			border-radius: 8px;
			background: rgba(255, 255, 255, 0.2);
			color: white;
			min-height: 30px;
			min-width: 200px;
		}

		.ptt-settings {
			background: rgba(255, 255, 255, 0.1);
			border-radius: 8px;
			padding: 15px;
			width: 100%;
			max-width: 400px;
		}

		.ptt-settings-title {
			color: white;
			font-weight: 600;
			margin-bottom: 15px;
			font-size: 1.1em;
		}

		.form-group {
			margin-bottom: 12px;
		}

		.form-group label {
			display: block;
			color: rgba(255, 255, 255, 0.9);
			font-size: 0.9em;
			margin-bottom: 5px;
			font-weight: 600;
		}

		.form-group input, .form-group select {
			width: 100%;
			padding: 10px;
			border: 2px solid rgba(255, 255, 255, 0.3);
			border-radius: 6px;
			background: rgba(255, 255, 255, 0.1);
			color: white;
			font-size: 1em;
			transition: all 0.2s ease;
		}

		.form-group input::placeholder {
			color: rgba(255, 255, 255, 0.6);
		}

		.form-group input:focus, .form-group select:focus {
			outline: none;
			border-color: white;
			background: rgba(255, 255, 255, 0.2);
		}

		.form-group select option {
			background: var(--dark);
			color: white;
		}

		.empty-state {
			text-align: center;
			padding: 40px 20px;
			color: #999;
		}

		.empty-state-title {
			font-size: 3em;
			margin-bottom: 15px;
		}

		.empty-state h3 {
			font-size: 1.3em;
			margin-bottom: 10px;
			color: var(--dark);
		}

		.delete-controls {
			display: none;
			position: fixed;
			bottom: 20px;
			left: 50%;
			transform: translateX(-50%);
			background: white;
			padding: 15px 30px;
			border-radius: 8px;
			box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
			z-index: 200;
		}

		.delete-controls.active {
			display: flex;
			gap: 10px;
			align-items: center;
		}

		.delete-count {
			font-weight: 600;
			color: var(--dark);
		}

		.btn-delete-selected {
			background: var(--danger);
			color: white;
			border: none;
			padding: 8px 16px;
			border-radius: 6px;
			cursor: pointer;
			font-weight: 600;
			transition: all 0.2s ease;
		}

		.btn-delete-selected:hover {
			background: #ff5252;
		}

		.btn-cancel-delete {
			background: var(--light);
			color: var(--dark);
			border: none;
			padding: 8px 16px;
			border-radius: 6px;
			cursor: pointer;
			font-weight: 600;
			transition: all 0.2s ease;
		}

		.btn-cancel-delete:hover {
			background: #e0e0e0;
		}

		.modal {
			display: none;
			position: fixed;
			top: 0;
			left: 0;
			right: 0;
			bottom: 0;
			background: rgba(0, 0, 0, 0.5);
			z-index: 1000;
			align-items: center;
			justify-content: center;
		}

		.modal.active {
			display: flex;
		}

		.modal-content {
			background: white;
			border-radius: 12px;
			padding: 30px;
			max-width: 500px;
			width: 90%;
			box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
		}

		.modal-title {
			font-size: 1.5em;
			font-weight: 700;
			margin-bottom: 20px;
			color: var(--dark);
		}

		.upload-area {
			border: 3px dashed var(--primary);
			border-radius: 8px;
			padding: 40px 20px;
			text-align: center;
			cursor: pointer;
			transition: all 0.2s ease;
			background: rgba(102, 126, 234, 0.05);
		}

		.upload-area:hover {
			border-color: var(--secondary);
			background: rgba(102, 126, 234, 0.1);
		}

		.upload-area.dragover {
			border-color: var(--secondary);
			background: rgba(102, 126, 234, 0.15);
			transform: scale(1.02);
		}

		.upload-area p {
			margin: 10px 0;
			color: var(--dark);
		}

		.upload-area p:first-child {
			font-size: 2em;
		}

		.upload-area p:nth-child(2) {
			font-weight: 600;
			font-size: 1.1em;
		}

		.upload-area p:last-child {
			font-size: 0.9em;
			color: #999;
		}

		input[type="file"] {
			display: none;
		}

		.modal-buttons {
			display: flex;
			gap: 10px;
			margin-top: 20px;
			justify-content: flex-end;
		}

		.btn-modal {
			padding: 10px 20px;
			border: none;
			border-radius: 6px;
			cursor: pointer;
			font-weight: 600;
			transition: all 0.2s ease;
		}

		.btn-cancel {
			background: var(--light);
			color: var(--dark);
		}

		.btn-cancel:hover {
			background: #e0e0e0;
		}

		.device-note {
			color: rgba(255, 255, 255, 0.7);
			font-size: 0.85em;
			margin-top: 10px;
			text-align: center;
		}

		@media (max-width: 768px) {
			header {
				flex-direction: column;
				align-items: stretch;
			}

			header h1 {
				width: 100%;
				text-align: center;
			}

			.header-buttons {
				width: 100%;
			}

			.btn-header {
				flex: 1;
				text-align: center;
			}

			.track-item {
				flex-direction: column;
				align-items: flex-start;
			}

			.ptt-button {
				width: 100px;
				height: 100px;
				font-size: 2em;
			}
		}
	</style>
</head>
<body>
	<header>
		<h1>🎵 Audio Player v2.0+</h1>
		<div class="header-buttons">
			<button class="btn-header btn-stop" onclick="stopAudio()">⏹️ Stop</button>
			<button class="btn-header btn-upload" onclick="openUploadModal()">📤 Upload</button>
			<button class="btn-header btn-delete-header" onclick="toggleDeleteMode()">🗑️ Delete</button>
		</div>
	</header>

	<div class="container">
		<div class="tabs">
			<button class="tab-btn active" onclick="switchTab('music')">🎵 Music</button>
			<button class="tab-btn" onclick="switchTab('ptt')">🎤 Voice (PTT)</button>
		</div>

		<div id="musicTab" class="tab-content active">
			<div id="trackList" class="track-list">
				<div class="empty-state">
					<div class="empty-state-title">🎵</div>
					<h3>Playlist is empty</h3>
					<p>Click Upload to add audio files</p>
				</div>
			</div>
		</div>

		<div id="pttTab" class="tab-content">
			<div class="ptt-section">
				<button class="ptt-button" id="pttBtn" onmousedown="startRecording()" onmouseup="stopRecording()" ontouchstart="startRecording()" ontouchend="stopRecording()">🎤</button>

				<div class="ptt-info">
					Hold button and speak into your microphone
				</div>

				<div class="ptt-status" id="pttStatus">Ready</div>

				<div class="ptt-settings">
					<div class="ptt-settings-title">Settings</div>

					<div class="form-group">
						<label>Router IP Address</label>
						<input type="text" id="routerIP" placeholder="192.168.1.1 (leave empty for local)">
						<div class="device-note">Leave empty to play on this device</div>
					</div>

					<div class="form-group">
						<label>Audio Device (Router)</label>
						<select id="audioDevice">
							<option value="hw:0,0">hw:0,0 (Default)</option>
							<option value="hw:0,1">hw:0,1</option>
							<option value="hw:1,0">hw:1,0</option>
							<option value="hw:1,1">hw:1,1</option>
							<option value="default">default</option>
						</select>
						<div class="device-note">Select audio output on router</div>
					</div>
				</div>
			</div>
		</div>
	</div>

	<div class="delete-controls" id="deleteControls">
		<span class="delete-count"><span id="selectedCount">0</span> selected</span>
		<button class="btn-delete-selected" onclick="deleteSelected()">Delete Selected</button>
		<button class="btn-cancel-delete" onclick="cancelDeleteMode()">Cancel</button>
	</div>

	<div id="uploadModal" class="modal">
		<div class="modal-content">
			<div class="modal-title">Upload Audio</div>
			<div class="upload-area" id="uploadArea">
				<p>🎧</p>
				<p>Drag files here</p>
				<p>or click to select</p>
				<input type="file" id="fileInput" accept=".mp3,.wav,.flac,.m4a" multiple>
			</div>
			<div class="modal-buttons">
				<button class="btn-modal btn-cancel" onclick="closeUploadModal()">Close</button>
			</div>
		</div>
	</div>

	<script>
		let deleteMode = false;
		let selectedTracks = new Set();
		let mediaRecorder;
		let audioChunks = [];
		let isRecording = false;

		loadPlaylist();
		setInterval(loadPlaylist, 2000);

		const uploadArea = document.getElementById('uploadArea');
		const fileInput = document.getElementById('fileInput');

		uploadArea.addEventListener('click', () => fileInput.click());

		uploadArea.addEventListener('dragover', (e) => {
			e.preventDefault();
			uploadArea.classList.add('dragover');
		});

		uploadArea.addEventListener('dragleave', () => {
			uploadArea.classList.remove('dragover');
		});

		uploadArea.addEventListener('drop', (e) => {
			e.preventDefault();
			uploadArea.classList.remove('dragover');
			handleFiles(e.dataTransfer.files);
		});

		fileInput.addEventListener('change', (e) => {
			handleFiles(e.target.files);
		});

		function switchTab(tab) {
			document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));
			document.querySelectorAll('.tab-btn').forEach(el => el.classList.remove('active'));
			
			if (tab === 'music') {
				document.getElementById('musicTab').classList.add('active');
			} else if (tab === 'ptt') {
				document.getElementById('pttTab').classList.add('active');
			}
			
			event.target.classList.add('active');
		}

		function openUploadModal() {
			document.getElementById('uploadModal').classList.add('active');
		}

		function closeUploadModal() {
			document.getElementById('uploadModal').classList.remove('active');
		}

		function toggleDeleteMode() {
			deleteMode = !deleteMode;
			selectedTracks.clear();
			document.querySelector('.btn-delete-header').classList.toggle('active');
			document.getElementById('deleteControls').classList.remove('active');
			loadPlaylist();
		}

		function cancelDeleteMode() {
			deleteMode = false;
			selectedTracks.clear();
			document.querySelector('.btn-delete-header').classList.remove('active');
			document.getElementById('deleteControls').classList.remove('active');
			loadPlaylist();
		}

		function toggleTrackSelection(trackId, event) {
			event.stopPropagation();
			if (selectedTracks.has(trackId)) {
				selectedTracks.delete(trackId);
			} else {
				selectedTracks.add(trackId);
			}
			updateSelectedCount();
			loadPlaylist();
		}

		function updateSelectedCount() {
			document.getElementById('selectedCount').textContent = selectedTracks.size;
			const controls = document.getElementById('deleteControls');
			if (selectedTracks.size > 0) {
				controls.classList.add('active');
			} else {
				controls.classList.remove('active');
			}
		}

		async function deleteSelected() {
			if (selectedTracks.size === 0) return;
			
			if (!confirm('Delete ' + selectedTracks.size + ' track(s)?')) return;

			const ids = Array.from(selectedTracks);
			const queryParams = ids.map(id => 'ids=' + encodeURIComponent(id)).join('&');

			try {
				await fetch('/api/remove-multiple?' + queryParams);
				selectedTracks.clear();
				deleteMode = false;
				document.querySelector('.btn-delete-header').classList.remove('active');
				document.getElementById('deleteControls').classList.remove('active');
				loadPlaylist();
			} catch (error) {
				console.error('Error:', error);
			}
		}

		function handleFiles(files) {
			if (files.length === 0) return;

			for (let file of files) {
				const formData = new FormData();
				formData.append('audio', file);
				formData.append('name', file.name.replace(/\.[^/.]+$/, ''));

				fetch('/api/add-track', {
					method: 'POST',
					body: formData
				})
				.then(r => r.json())
				.then(data => {
					loadPlaylist();
				})
				.catch(err => console.error('Error:', err));
			}

			fileInput.value = '';
			setTimeout(closeUploadModal, 500);
		}

		async function loadPlaylist() {
			try {
				const response = await fetch('/api/playlist');
				const playlist = await response.json();

				const trackList = document.getElementById('trackList');

				if (!playlist.items || playlist.items.length === 0) {
					trackList.innerHTML = '<div class="empty-state"><div class="empty-state-title">🎵</div><h3>Playlist is empty</h3><p>Click Upload to add audio files</p></div>';
					return;
				}

				let html = '';

				playlist.items.forEach(track => {
					const isPlaying = track.duration === 1;
					const statusClass = isPlaying ? 'playing' : '';
					const isSelected = selectedTracks.has(track.id);
					const selectedClass = isSelected ? 'selected' : '';
					const playIcon = isPlaying ? ' (Playing)' : '';

					let checkboxHtml = '';
					if (deleteMode) {
						checkboxHtml = '<input type="checkbox" class="track-checkbox visible" ' + (isSelected ? 'checked' : '') + ' onclick="toggleTrackSelection(\'' + track.id + '\', event)">';
					}

					html += '<div class="track-item ' + statusClass + ' ' + selectedClass + '" onclick="' + (deleteMode ? 'toggleTrackSelection(\'' + track.id + '\', event)' : 'playTrack(\'' + track.id + '\')') + '">' + checkboxHtml + '<div class="track-number">' + track.number + '</div><div class="track-info"><div class="track-name">' + escapeHtml(track.name) + playIcon + '</div><div class="track-meta">Added ' + new Date(track.added * 1000).toLocaleDateString() + '</div></div></div>';
				});

				trackList.innerHTML = html;
			} catch (error) {
				console.error('Error:', error);
			}
		}

		async function playTrack(trackId) {
			if (deleteMode) return;
			
			try {
				await fetch('/api/play?id=' + trackId);
				loadPlaylist();
			} catch (error) {
				console.error('Error:', error);
			}
		}

		async function stopAudio() {
			try {
				await fetch('/api/stop');
				loadPlaylist();
			} catch (error) {
				console.error('Error:', error);
			}
		}

		// ==================== PTT (Voice) Functions ====================

		async function startRecording() {
			if (isRecording) return;

			try {
				const stream = await navigator.mediaDevices.getUserMedia({ 
					audio: { 
						echoCancellation: true, 
						noiseSuppression: true,
						autoGainControl: true
					} 
				});

				mediaRecorder = new MediaRecorder(stream, {
					mimeType: 'audio/webm;codecs=opus',
					audioBitsPerSecond: 128000
				});

				audioChunks = [];

				mediaRecorder.ondataavailable = (event) => {
					audioChunks.push(event.data);
				};

				mediaRecorder.start();
				isRecording = true;

				document.getElementById('pttBtn').classList.add('recording');
				document.getElementById('pttStatus').textContent = '🔴 Recording...';

			} catch (err) {
				document.getElementById('pttStatus').textContent = '❌ Microphone access denied';
				console.error('Error:', err);
			}
		}

		function stopRecording() {
			if (!isRecording || !mediaRecorder) return;

			mediaRecorder.stop();
			isRecording = false;

			document.getElementById('pttBtn').classList.remove('recording');
			document.getElementById('pttStatus').textContent = '⏳ Sending...';

			mediaRecorder.onstop = () => {
				const audioBlob = new Blob(audioChunks, { type: 'audio/webm' });
				sendAudio(audioBlob);

				mediaRecorder.stream.getTracks().forEach(track => track.stop());
			};
		}

		async function sendAudio(audioBlob) {
			const routerIP = document.getElementById('routerIP').value.trim();
			const audioDevice = document.getElementById('audioDevice').value;

			try {
				let url = '/api/voice?router=' + encodeURIComponent(routerIP);
				url += '&device=' + encodeURIComponent(audioDevice);

				const response = await fetch(url, {
					method: 'POST',
					body: audioBlob,
					headers: {
						'Content-Type': 'audio/webm'
					}
				});

				const data = await response.json();

				if (data.status === 'received') {
					document.getElementById('pttStatus').textContent = '✅ Playing on ' + (routerIP ? routerIP : 'this device');
					setTimeout(() => {
						document.getElementById('pttStatus').textContent = 'Ready';
					}, 2000);
				}
			} catch (error) {
				document.getElementById('pttStatus').textContent = '❌ Error: ' + error.message;
				console.error('Error:', error);
			}
		}

		document.addEventListener('DOMContentLoaded', () => {
			const savedRouter = localStorage.getItem('routerIP');
			if (savedRouter) {
				document.getElementById('routerIP').value = savedRouter;
			}

			document.getElementById('routerIP').addEventListener('change', (e) => {
				localStorage.setItem('routerIP', e.target.value);
			});
		});

		function escapeHtml(text) {
			const div = document.createElement('div');
			div.textContent = text;
			return div.innerHTML;
		}
	</script>
</body>
</html>`
}

func main() {
	http.HandleFunc("/api/playlist", handleGetPlaylist)
	http.HandleFunc("/api/add-track", handleAddTrack)
	http.HandleFunc("/api/remove-track", handleRemoveTrack)
	http.HandleFunc("/api/remove-multiple", handleRemoveMultiple)
	http.HandleFunc("/api/play", handlePlay)
	http.HandleFunc("/api/stop", handleStop)
	http.HandleFunc("/api/voice", handleVoiceData)
	http.HandleFunc("/api/play-voice", handlePlayVoice)
	http.HandleFunc("/", handleIndex)

	fmt.Println("\n╔════════════════════════════════════════════════════════════╗")
	fmt.Println("║     🎵 Keenetic Audio Player v2.0+ with PTT              ║")
	fmt.Println("╚════════════════════════════════════════════════════════════╝")
	fmt.Printf("\n🌐 Web Interface: http://0.0.0.0%s\n", PORT)
	fmt.Printf("📁 Media Directory: %s\n", appState.mediaDir)
	fmt.Printf("📊 Installation Dir: %s\n\n", appState.installDir)

	if err := http.ListenAndServe(PORT, nil); err != nil {
		fmt.Printf("❌ Error: %v\n", err)
	}
}
