package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
	"unsafe"

	"github.com/PuerkitoBio/goquery"
	"golang.org/x/net/publicsuffix"
)

type DailyRecord struct {
	Index   string `json:"index"`
	Date    string `json:"date"`
	Time    string `json:"time"`
	Status  string `json:"status"`
	Remarks string `json:"remarks"`
}

type AttendanceInfo struct {
	SubjectName  string        `json:"subject_name"`
	Percent      string        `json:"percent"`
	LatestClass  string        `json:"latest_class"`
	DailyRecords []DailyRecord `json:"daily_records"`
}

type TargetSubject struct {
	Name     string
	ViewLink string
	Semester int
}

func main() {}

//export FetchAttendanceFFI
func FetchAttendanceFFI(username *C.char, password *C.char) *C.char {
	res := FetchAttendance(C.GoString(username), C.GoString(password))
	return C.CString(res)
}

//export FreeString
func FreeString(s *C.char) {
	if s != nil {
		C.free(unsafe.Pointer(s))
	}
}

func extractSemester(text string) int {
	text = strings.ToLower(text)
	
	// Simplified matcher for format Semester -X or Sem 1, etc.
	re := regexp.MustCompile(`(semester|sem)\s*[- ]*\s*(\d+)`)
	matches := re.FindStringSubmatch(text)
	if len(matches) >= 3 {
		val, _ := strconv.Atoi(matches[2])
		return val
	}
	
	return 0
}

func FetchAttendance(username string, password string) string {
	loginURL := "https://dcrustm.samarth.edu.in/index.php/site/login"
	attendanceURL := "https://dcrustm.samarth.edu.in/index.php/student-attendance/attendance/index?per-page=50"

	jar, err := cookiejar.New(&cookiejar.Options{PublicSuffixList: publicsuffix.List})
	if err != nil {
		return fmt.Sprintf(`{"error": "Error creating cookie jar: %v"}`, err)
	}

	client := &http.Client{
		Jar:     jar,
		Timeout: 30 * time.Second,
	}

	req, _ := http.NewRequest("GET", loginURL, nil)
	req.Header.Set("User-Agent", "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36")

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Sprintf(`{"error": "Failed to GET login page (Network/SSL error): %v"}`, err)
	}
	defer resp.Body.Close()

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return fmt.Sprintf(`{"error": "Failed to parse login page: %v"}`, err)
	}
	csrfToken, exists := doc.Find(`meta[name="csrf-token"]`).Attr("content")
	if !exists || csrfToken == "" {
		csrfToken, _ = doc.Find(`input[name="_csrf"]`).Attr("value")
	}

	formData := url.Values{}
	formData.Set("_csrf", csrfToken)
	formData.Set("LoginForm[username]", username)
	formData.Set("LoginForm[password]", password)
	formData.Set("login-button", "")

	_ = formData.Encode() // To silence lint error about unused formData.Encode() if needed
	postReq, _ := http.NewRequest("POST", loginURL, strings.NewReader(formData.Encode()))
	postReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	postReq.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
	postReq.Header.Set("Referer", loginURL)

	postResp, err := client.Do(postReq)
	if err != nil {
		return fmt.Sprintf(`{"error": "Failed to POST login: %v"}`, err)
	}
	defer postResp.Body.Close()

	if strings.Contains(postResp.Request.URL.Path, "site/login") {
		return `{"error": "Login failed: Incorrect username or password."}`
	}

	var allPossibleTargets []TargetSubject
	currentURL := attendanceURL
	maxSemester := 0
	visited := make(map[string]bool)
	pageCount := 0
	const maxPages = 50

	// FIRST PASS: Discover all subjects and find the MAXIMUM semester
	for {
		if visited[currentURL] {
			fmt.Printf("Loop detected in subject discovery: %s\n", currentURL)
			break
		}
		visited[currentURL] = true
		pageCount++
		if pageCount > maxPages {
			fmt.Printf("Max pages (%d) reached in subject discovery\n", maxPages)
			break
		}

		fmt.Printf("Scanning subjects page %d: %s\n", pageCount, currentURL)
		attReq, _ := http.NewRequest("GET", currentURL, nil)
		attReq.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")

		attResp, err := client.Do(attReq)
		if err != nil || attResp.StatusCode != 200 {
			break
		}

		attDoc, err := goquery.NewDocumentFromReader(attResp.Body)
		attResp.Body.Close()
		if err != nil {
			break
		}

		attDoc.Find("table tbody tr, table tr").Each(func(i int, s *goquery.Selection) {
			text := strings.ToLower(s.Text())
			sem := extractSemester(text)
			
			if sem > 0 {
				if sem > maxSemester {
					maxSemester = sem
				}
				
				var rawName string
				tds := s.Find("td")
				if tds.Length() >= 3 {
					rawName = strings.TrimSpace(tds.Eq(2).Text())
				}
				
				var link string
				s.Find("a, button").EachWithBreak(func(j int, a *goquery.Selection) bool {
					titleAttr, _ := a.Attr("title")
					if strings.Contains(strings.ToLower(a.Text()), "view") || strings.Contains(strings.ToLower(titleAttr), "view") {
						href, exists := a.Attr("href")
						if exists { link = href }
						return false
					}
					return true
				})

				if link != "" {
					// Use resolve reference to handle both relative and absolute links properly
					baseURL, _ := url.Parse(currentURL)
					rel, _ := url.Parse(link)
					fullLink := baseURL.ResolveReference(rel).String()

					allPossibleTargets = append(allPossibleTargets, TargetSubject{
						Name:     strings.Join(strings.Fields(strings.ReplaceAll(strings.ReplaceAll(rawName, "\n", " "), "\t", " ")), " "),
						ViewLink: fullLink,
						Semester: sem,
					})
				}
			}
		})

		nextA := attDoc.Find("ul.pagination li.next:not(.disabled) a")
		if nextA.Length() > 0 {
			nextHref, exists := nextA.Attr("href")
			if exists && nextHref != "" && nextHref != "#" {
				if strings.HasPrefix(nextHref, "/") {
					currentURL = "https://dcrustm.samarth.edu.in" + nextHref
				} else {
					baseURL, _ := url.Parse(currentURL)
					rel, _ := url.Parse(nextHref)
					currentURL = baseURL.ResolveReference(rel).String()
				}
				continue
			}
		}
		break
	}

	// Filter to keep only subjects from the MAX semester
	var targets []TargetSubject
	for _, t := range allPossibleTargets {
		if t.Semester == maxSemester {
			targets = append(targets, t)
		}
	}

	var results []AttendanceInfo
	var wg sync.WaitGroup
	var mu sync.Mutex

	for i, target := range targets {
		if target.ViewLink != "" {
			wg.Add(1)
			go func(idx int, t TargetSubject) {
				defer wg.Done()
				info := fetchDetailAttendance(client, t.ViewLink, t.Name)
				mu.Lock()
				results = append(results, info)
				mu.Unlock()
			}(i, target)
		}
	}
	wg.Wait()

	jsonData, err := json.Marshal(results)
	if err != nil {
		return fmt.Sprintf(`{"error": "Failed to marshal JSON: %v"}`, err)
	}
	return string(jsonData)
}

func fetchDetailAttendance(client *http.Client, urlStr string, subjectName string) AttendanceInfo {
	var info AttendanceInfo
	info.SubjectName = subjectName
	currentURL := urlStr
	firstPage := true
	pageNum := 1 // track current page for numbered-pagination detection
	visited := make(map[string]bool)
	const maxPages = 50

	for {
		if visited[currentURL] {
			fmt.Printf("[%s] Loop detected in detail fetch: %s\n", subjectName, currentURL)
			break
		}
		if pageNum > maxPages {
			fmt.Printf("[%s] Max pages (%d) reached in detail fetch\n", subjectName, maxPages)
			break
		}
		visited[currentURL] = true

		fmt.Printf("[%s] Fetching records page %d: %s\n", subjectName, pageNum, currentURL)
		req, _ := http.NewRequest("GET", currentURL, nil)
		req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
		resp, err := client.Do(req)
		if err != nil { break }
		doc, err := goquery.NewDocumentFromReader(resp.Body)
		resp.Body.Close()
		if err != nil { break }

		if firstPage {
			var percent string
			doc.Find("th").Each(func(i int, s *goquery.Selection) {
				headerText := strings.ToLower(strings.TrimSpace(s.Text()))
				if headerText == "present percentage" || headerText == "present percent" {
					nextTd := s.Next()
					if nextTd.Length() > 0 { percent += "Percentage: " + strings.TrimSpace(nextTd.Text()) + " " }
				} else if headerText == "attendance summary" {
					nextTd := s.Next()
					if nextTd.Length() > 0 { percent += "[" + strings.TrimSpace(nextTd.Text()) + "] " }
				}
			})
			info.Percent = strings.TrimSpace(percent)
			if info.Percent == "" { info.Percent = "No percentage found." }
			firstPage = false
		}

		doc.Find("table tbody tr").Each(func(i int, s *goquery.Selection) {
			tds := s.Find("td")
			if tds.Length() >= 4 {
				index := strings.TrimSpace(tds.Eq(0).Text())
				if strings.ToLower(index) != "no results found." && index != "" {
					rec := DailyRecord{
						Index:  index,
						Date:   strings.TrimSpace(tds.Eq(1).Text()),
						Time:   strings.TrimSpace(tds.Eq(2).Text()),
						Status: strings.TrimSpace(tds.Eq(3).Text()),
					}
					if tds.Length() >= 5 { rec.Remarks = strings.TrimSpace(tds.Eq(4).Text()) }
					info.DailyRecords = append(info.DailyRecords, rec)
				}
			}
		})

		nextURL := findNextPageURL(doc, urlStr, pageNum)
		if nextURL != "" {
			currentURL = nextURL
			pageNum++
			continue
		}
		break
	}

	if len(info.DailyRecords) > 0 {
		lastRecord := info.DailyRecords[len(info.DailyRecords)-1]
		info.LatestClass = fmt.Sprintf("%s at %s (%s)", lastRecord.Date, lastRecord.Time, lastRecord.Status)
	} else {
		info.LatestClass = "No daily records found"
	}
	return info
}

// findNextPageURL detects the next-page URL from Samarth/Yii2 pagination.
// It handles three styles seen on the portal:
//  1. Bootstrap 3 / Yii2 default:  <li class="next"> <a href="...">
//  2. Bootstrap 4/5 numbered-only: <li class="page-item"> <a class="page-link">2</a>
//     (no "Next" button — active page is li.page-item.active, next pages are
//     plain li.page-item with numbered links, as seen in the DevTools screenshot)
//  3. Universal fallback: any pagination link whose visible text is "next"/"»"
func findNextPageURL(doc *goquery.Document, baseURLStr string, currentPage int) string {
	resolve := func(href string) string {
		base, _ := url.Parse(baseURLStr)
		rel, _ := url.Parse(href)
		return base.ResolveReference(rel).String()
	}

	// --- Strategy 1: Bootstrap 3 / Yii2 "Next" <li class="next"> ---
	nextA := doc.Find("ul.pagination li.next:not(.disabled) a")
	if nextA.Length() > 0 {
		if href, exists := nextA.Attr("href"); exists && href != "" && href != "#" {
			return resolve(href)
		}
	}

	// --- Strategy 2: Bootstrap 4/5 numbered pagination ---
	// Active page: li.page-item.active; next page link text == currentPage+1.
	// Also accept data-page attribute (0-indexed) == currentPage.
	nextPageText := strconv.Itoa(currentPage + 1)
	var numberedURL string
	doc.Find("ul.pagination li.page-item:not(.active):not(.disabled) a.page-link").EachWithBreak(func(_ int, s *goquery.Selection) bool {
		text := strings.TrimSpace(s.Text())
		dataPage, hasDataPage := s.Attr("data-page")
		if text == nextPageText {
			if href, exists := s.Attr("href"); exists && href != "" && href != "#" {
				numberedURL = resolve(href)
				return false
			}
		}
		// data-page is 0-indexed, so page 2 has data-page="1" == currentPage
		if hasDataPage && dataPage == strconv.Itoa(currentPage) {
			if href, exists := s.Attr("href"); exists && href != "" && href != "#" {
				numberedURL = resolve(href)
				return false
			}
		}
		return true
	})
	if numberedURL != "" {
		return numberedURL
	}

	// --- Strategy 3: text-based fallback ---
	var fallbackURL string
	doc.Find("ul.pagination li a").EachWithBreak(func(_ int, s *goquery.Selection) bool {
		t := strings.ToLower(strings.TrimSpace(s.Text()))
		if t == "next" || t == "\u00bb" || t == "\u203a" || strings.Contains(t, "next") {
			if href, exists := s.Attr("href"); exists && href != "" && href != "#" {
				fallbackURL = resolve(href)
				return false
			}
		}
		return true
	})
	return fallbackURL
}
